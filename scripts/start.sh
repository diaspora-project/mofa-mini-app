#!/bin/bash
# Entrypoint for every mofa-mini-app container. One image, three knobs:
#
#   STREAM_ENGINE   files | mofka | octopus   (DiasporaQueues backend)
#   LAUNCH_OPTION   both  | thinker | server  (which half of the workflow)
#   MOFA_QUEUE_PREFIX                          (SHARED topic prefix; thinker and
#                                               server of one deployment MUST match)
#
# Supporting env:
#   MONGO_HOST   the server reaches the thinker's mongod here
#   MOFA_MOFKA_GROUP_FILE  bedrock flock file (mofka); on a shared volume so the
#                server can read what the thinker's bedrock wrote
#
# See docker-compose.yml (octopus / mofka profiles). The thinker/server split
# is selected via run_parallel_workflow.py's --launch-option flag.
set -euo pipefail

# Thread-pool caps — librdkafka starves under unbounded BLAS workers, and
# bedrock has lost the per-user thread budget before (envs/chameleon-stream.md §8).
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1

: "${STREAM_ENGINE:=files}"
: "${LAUNCH_OPTION:=both}"
: "${MONGO_HOST:=localhost}"
: "${MOFA_QUEUE_PREFIX:=}"
: "${MOFA_SIM_BUDGET:=4}"
# CloudVMConfig (configs/cloud-vm.py) reads these env overrides for the
# simulation executables:
#   MOFA_LAMMPS_BIN -> wrapper that runs the ACEsuit `mace` lmp with libtorch
#                      on LD_LIBRARY_PATH.
#   MOFA_CP2K_BIN   -> cp2k_shell.ssmp DFT wrapper, installed into the conda
#                      env bin/ by docker/Dockerfile-cpu (remote) or the
#                      first-start block below (local bind-mount).
export MOFA_LAMMPS_BIN=/opt/scripts/lmp-mace.sh
export MOFA_CP2K_BIN=cp2k_shell.ssmp

echo "STREAM_ENGINE=$STREAM_ENGINE  LAUNCH_OPTION=$LAUNCH_OPTION" \
     " MONGO_HOST=$MONGO_HOST  PREFIX=${MOFA_QUEUE_PREFIX:-<random-per-process>}"

is_thinker() { [ "$LAUNCH_OPTION" = both ] || [ "$LAUNCH_OPTION" = thinker ]; }
is_server()  { [ "$LAUNCH_OPTION" = both ] || [ "$LAUNCH_OPTION" = server ];  }

# Block until host:port accepts a TCP connection (no extra deps; uses /dev/tcp).
wait_for_tcp() {
  local host=$1 port=$2 tries=${3:-180}
  echo "waiting for $host:$port ..."
  for _ in $(seq 1 "$tries"); do
    if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then
      exec 3>&- 3<&-; echo "$host:$port is up"; return 0
    fi
    sleep 1
  done
  echo "timed out waiting for $host:$port" >&2; return 1
}

cd /opt/mof-generation-at-scale

# MOFA_SOURCE=local bind-mount: the at-build mutations were skipped (no
# /opt/.mofa-prebuilt marker), so apply them now, idempotently, against the
# bind-mounted tree. A remote-built image has the marker and skips this.
if [ ! -f /opt/.mofa-prebuilt ]; then
  echo "First-start setup against bind-mounted tree..."
  pip install -e ".[test]"
  sed -i "s|~/libtorch|/opt/libtorch|g; s|~/lammps/build-mace/bin/lmp|/opt/lammps/build-mace/bin/lmp|g" \
    mofa/hpc/config.py
  # The thinker/server split is selected at runtime via --launch-option, so the
  # bind-mounted tree needs no source mutation for it.
  ( cd input-files/zn-paddle-pillar && python assemble_inputs.py )
  # Drop --format mliap (see docker/Dockerfile-cpu): this image's LAMMPS is
  # PKG_ML-MACE (libtorch format), and mliap crashes mace 0.3.13's converter.
  ( cd input-files/mace && sed -i 's| --format mliap||' get-macemp-0a.sh && ./get-macemp-0a.sh )
  # CP2K shell wrapper (see docker/Dockerfile-cpu); needs cp2k.ssmp on PATH.
  CONDA_PREFIX=/opt/conda/envs/mofa bash bin/install-cp2k-shell-wrapper.sh
fi

# Thinker/server split flags for run_parallel_workflow.py
# (--launch-option / --mongo-host / --queue-prefix). A thinker and a server
# meet on the queue only when they share --queue-prefix.
ROLE_ARGS=(--launch-option "$LAUNCH_OPTION" --mongo-host "$MONGO_HOST")
[ -n "$MOFA_QUEUE_PREFIX" ] && ROLE_ARGS+=(--queue-prefix "$MOFA_QUEUE_PREFIX")

ENGINE_ARGS=(--stream-engine "$STREAM_ENGINE")

# --- mofka: bedrock daemon --------------------------------------------------
if [ "$STREAM_ENGINE" = "mofka" ]; then
  : "${MOFA_MOFKA_GROUP_FILE:=/shared/mofka/mofka.flock.json}"
  bedrock_dir=$(dirname "$MOFA_MOFKA_GROUP_FILE")
  mkdir -p "$bedrock_dir"

  # The mofka client (both halves) dlopens lmdb/leveldb via libyokan-client.so.
  P=/opt/conda/envs/mofa/lib
  export LD_PRELOAD="$P/liblmdb.so:$P/libleveldb.so${LD_PRELOAD:+:$LD_PRELOAD}"
  export LD_LIBRARY_PATH="$P${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

  if is_thinker; then
    # Canonical launcher: ofi+tcp (Parsl-fork-safe; na+sm hangs forked workers
    # and is blocked by Yama across containers — see docs/adr/0001). It binds
    # loopback, so the server shares this container's netns (docker-compose
    # network_mode) to reach it. start-bedrock.py leaves bedrock running and
    # returns once the flock file exists.
    rm -f "$bedrock_dir"/mofka.flock.json "$bedrock_dir"/bedrock-config*.json
    CONDA_PREFIX=/opt/conda/envs/mofa \
      python bin/start-bedrock.py "$bedrock_dir"
  fi

  # Everyone waits for a fresh flock file (the server has no bedrock of its own).
  for _ in $(seq 1 60); do
    [ -s "$MOFA_MOFKA_GROUP_FILE" ] && break
    sleep 1
  done
  if [ ! -s "$MOFA_MOFKA_GROUP_FILE" ]; then
    echo "bedrock group file $MOFA_MOFKA_GROUP_FILE never appeared" >&2
    [ -f "$bedrock_dir/bedrock.log" ] && tail -n 50 "$bedrock_dir/bedrock.log" >&2
    exit 1
  fi
  ENGINE_ARGS+=(--mofka-group-file "$MOFA_MOFKA_GROUP_FILE")
fi

# --- server: wait for the thinker's mongod ----------------------------------
# run_parallel_workflow.py calls initialize_database() against MONGO_HOST in
# every role, so a server-only container must wait for the thinker's mongod.
if is_server && ! is_thinker; then
  wait_for_tcp "$MONGO_HOST" 27017
fi

# --- run --------------------------------------------------------------------
echo "launching run_parallel_workflow.py ${ROLE_ARGS[*]} ${ENGINE_ARGS[*]}"
# Workflow knobs are kept IN SYNC with the native benchmark runner
# (mof-generation-at-scale/bin/run-bench-cloud-vm.sh) so container-vs-native
# streaming traces are apples-to-apples. The only intended difference is the
# thinker/server split (--launch-option, via ROLE_ARGS). For a benchmark run set
# MOFA_SIM_BUDGET=100000 so it never exits early (see docker-compose.yml header).
exec python -u run_parallel_workflow.py \
  --node-path input-files/zn-paddle-pillar/node.json \
  --generator-path models/geom-300k/geom_difflinker_epoch=997_new.ckpt \
  --generator-config-path models/geom-300k/config-tf32-a100.yaml \
  --ligand-templates input-files/zn-paddle-pillar/template_*_prompt.yml \
  --retrain-freq 2 \
  --num-epochs 2 \
  --num-samples 8 \
  --gen-batch-size 8 \
  --molecule-sizes 8 10 12 \
  --simulation-budget "$MOFA_SIM_BUDGET" \
  --mace-model-path ./input-files/mace/mace-mp0_medium-lammps.pt \
  --md-timesteps 200 \
  --dft-opt-steps 2 \
  --compute-config configs/cloud-vm.py \
  "${ROLE_ARGS[@]}" \
  "${ENGINE_ARGS[@]}"
