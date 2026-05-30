# MOFA Diaspora Mini-App (CPU)

CPU-only Docker mini-app for the MOFA parallel workflow, run as a
**thinker + server** split over
[`mofa.diaspora.DiasporaQueues`](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/mofa/diaspora.py),
against two stream backends:

- **`octopus`** — AWS MSK Kafka via the Diaspora event SDK + Globus auth.
- **`mofka`** — local single-host bedrock daemon (mochi-margo, `ofi+tcp`).

Tracks the cloud-VM setup documented in
[`mof-generation-at-scale/envs/chameleon-stream.md`](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/envs/chameleon-stream.md).

## Architecture

`run_parallel_workflow.py` splits into two roles via
`--launch-option {both,thinker,server}` (plus `--mongo-host` and
`--queue-prefix`); `scripts/start.sh` sets those flags per role. With
`--launch-option both` (the default) one process runs the whole workflow.
The two split roles:

| Role | Runs | Talks to |
|---|---|---|
| **thinker** | MongoDB + `MOFAThinker` (steering: submits/gathers tasks) | the queue + its own mongod |
| **server** | `ParslTaskServer` (executes generation / LAMMPS / CP2K / RASPA / assembly) | the queue + the thinker's mongod |

The two halves rendezvous on the queue **only if they share a topic prefix**;
upstream mints a *random* prefix per process, so the mini-app pins
`MOFA_QUEUE_PREFIX` identically on both halves.

```
mofa-mini-app/
├── docker/Dockerfile-cpu       # one CPU image for every role/backend
├── envs/environment-cpu.yml    # CPU superset of environment-chameleon-stream.yml
├── scripts/
│   ├── start.sh                # entrypoint; role- & backend-aware
│   └── lmp-mace.sh             # LAMMPS launcher scoping libtorch for pair_style mace
├── docker-compose.yml          # profiles: octopus, mofka, files
├── .env.template               # copy to .env (gitignored); optional for octopus
└── README.md
```

### Topology per backend

- **octopus** (`--profile octopus`) — `octopus-thinker` and `octopus-server`,
  independent containers that rendezvous on cloud Kafka; the server reaches the
  thinker's mongod by service name. Both mint AWS keys from cached Globus tokens
  (the `diaspora-storage` volume).
- **mofka** (`--profile mofka`) — `mofka-thinker` runs a **loopback `ofi+tcp`
  bedrock daemon** (`bin/start-bedrock.py`; Parsl-fork-safe — `na+sm` hangs
  forked workers and is blocked by Yama across containers, see
  [ADR-0001](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/docs/adr/0001-mofka-bedrock-transport.md)).
  `mofka-server` **shares the thinker's network namespace**
  (`network_mode: service:mofka-thinker`) so it reaches the loopback bedrock
  and mongod. The flock file is handed over the `mofka-shared` volume.
- **files** (`--profile files`) — a single `workflow-files` container,
  `LAUNCH_OPTION=both`, on-disk topics, no external service. Quickest smoke.

## Prerequisites

- Docker + Docker Compose v2
- (octopus only) a Globus account with Diaspora/Octopus access, for the
  one-time token bootstrap

> If your user isn't in the `docker` group, prefix every `docker` / `docker
> compose` command below with `sudo` (the commands are written without it).

## Build

```bash
docker compose --profile files build      # builds the shared mofa-mini-app:cpu image
```

The build pulls `ubuntu:24.04`, installs Miniconda (accepting the Anaconda ToS
non-interactively), downloads the pinned mochi-hpc conda channel
(`MOCHI_TAG=2026-05-30`), creates the `mofa` conda env, downloads libtorch
(CPU 2.5.1), compiles LAMMPS with MACE support (`PKG_ML-MACE` → pair_style mace,
libtorch model format), installs conda-forge `cp2k` plus the `cp2k_shell.ssmp`
wrapper (DFT), and clones the MOFA source.
Cold build ~20–30 min (LAMMPS + cp2k dominate); image ~9–13 GB. The build's
last step runs
[`tests/smoke_stream_env.py`](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/tests/smoke_stream_env.py)
and fails if any of the stream imports is missing.

### Build-arg knobs

| Arg | Default | Purpose |
|---|---|---|
| `MOFA_SOURCE` | `remote` | `remote` clones MOFA at build; `local` skips the clone and expects a bind-mount at runtime. |
| `MOFA_BRANCH` | `diaspora-debug` | Branch to check out when `MOFA_SOURCE=remote`. |
| `MOFA_REMOTE` | `https://github.com/globus-labs/mof-generation-at-scale.git` | Git remote to clone. |
| `MOCHI_TAG` | `2026-05-30` | mochi-conda-packages release (mofka 0.9.0 / yokan 0.9.2 / bedrock 0.16.1). Keep in lockstep with mof-generation's `environment-chameleon-stream.yml`; a tag where yokan and `diaspora-stream-octopus` disagree on the libuuid/util-linux pin breaks the solve (see `chameleon-stream.md` Troubleshooting). |

## Run

```bash
docker compose --profile mofka   up --build   # local bedrock daemon
docker compose --profile octopus up --build   # AWS MSK Kafka (needs token bootstrap)
docker compose --profile files   up --build   # single-container smoke, no deps
```

Each role runs
[`run_parallel_workflow.py`](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/run_parallel_workflow.py)
with a small `--simulation-budget` (4). Stop within ~15 min:

```bash
docker compose --profile <name> down
```

A 15-min run reliably exercises generation, assembly, and the queue round-trip.
Whether it reaches the MD/DFT stages depends on CPU compute speed — CPU DFT is
slow (see the DFT-on-CPU note below), so a short run may stop before finishing
DFT; that's expected, not a fault. The workflow knobs in `scripts/start.sh`
(`--md-timesteps`, `--gen-batch-size`, `--molecule-sizes`, `--num-epochs`, …)
are kept in sync with the native benchmark runner
(`mof-generation-at-scale/bin/run-bench-cloud-vm.sh`) so container and native
streaming traces are apples-to-apples; the only intended difference is the
thinker/server split.

### Benchmark (timed 1-hour run)

Benchmarking is **on by default** — `DiasporaQueues` writes one JSON record per
timed queue op to a per-PID trace. Each profile bind-mounts
`./bench-out/<profile>` over the workflow's `run/`, so traces land on the host
and survive `down`.

There is no duration flag — a container run is **wall-clock**: you `up`, wait,
then `down`. `MOFA_SIM_BUDGET` is the simulation *count* that ends the run early,
so set it huge to keep the workflow streaming for the whole window;
`MOFA_QUEUE_PREFIX` is the shared topic prefix both halves meet on.

```bash
# 1-hour mofka benchmark (loopback bedrock; no credentials)
MOFA_SIM_BUDGET=100000 MOFA_QUEUE_PREFIX=mofa_bench \
    docker compose --profile mofka up -d
sleep 3600                                   # wall-clock; then stop
docker compose --profile mofka down
sudo chown -R "$USER" bench-out              # container traces are root-owned
~/mof-generation-at-scale/bin/analyze-bench.py bench-out/mofka
```

For **octopus**, seed the cached Globus tokens first (see the bootstrap section
below), use a fresh `MOFA_QUEUE_PREFIX`, and clean its topics afterward
(`tests/smoke_octopus.py --prefix <prefix> --no-rotate-keys`).

The pipeline is compute-gated on CPU DFT, so streaming is busiest in the first
~10 min and then tapers — the per-op *latencies* are stable regardless of run
length. Full measured tables live in
[`chameleon-stream.md` §4](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/envs/chameleon-stream.md).

## One-time Octopus token bootstrap

`mofa.diaspora.DiasporaQueues` mints fresh AWS keys at startup via
`GlobusClient.create_key()`, reading cached Globus tokens from
`~/.diaspora/storage.db`. The first call walks an **interactive Globus login**;
the `diaspora-storage` named volume persists the tokens for both octopus
containers thereafter.

```bash
docker compose --profile octopus run --rm octopus-thinker python tests/smoke_octopus.py
```

The same script clears stale Kafka topics; re-run it after a crashed workflow
if librdkafka starts complaining about "Unable to create broker thread".

## Backend / role selection

`scripts/start.sh` reads three env vars (set per service in
`docker-compose.yml`):

| Var | Values | Meaning |
|---|---|---|
| `STREAM_ENGINE` | `files` \| `mofka` \| `octopus` | DiasporaQueues backend (passed as `--stream-engine`). |
| `LAUNCH_OPTION` | `both` \| `thinker` \| `server` | Which half of the workflow runs. |
| `MOFA_QUEUE_PREFIX` | string | **Shared** topic prefix; thinker and server of one deployment MUST match. |

Supporting vars: `MONGO_HOST` (where the server finds the thinker's mongod),
`MOFA_MOFKA_GROUP_FILE` (bedrock flock file on the shared volume).

## Local source override

```bash
MOFA_SOURCE=local docker compose --profile mofka build
# then uncomment the bind-mount line under each service's `volumes:` and adjust
# the host path. start.sh runs the build-time source mutations on first start.
```

## Known issues / notes

See the [`chameleon-stream.md` Troubleshooting table](https://github.com/globus-labs/mof-generation-at-scale/blob/diaspora-debug/envs/chameleon-stream.md#troubleshooting)
for the upstream gotcha list. Inside Docker specifically:

- **mofka transport** — bedrock uses `ofi+tcp` (loopback), never `na+sm`:
  `na+sm` deadlocks Parsl-forked workers on `/dev/shm` and is blocked by Yama
  across containers. This is why the mofka server shares the thinker's network
  namespace rather than connecting over the compose network (loopback bind is
  single-host by design; routable multi-host mofka is future work).
- **Thread caps** — `start.sh` exports `OPENBLAS_NUM_THREADS=1` (and friends)
  so numpy/MKL don't starve librdkafka / Argobots of threads.
- **mochi channel tag** — pinned to `2026-05-30` (mofka 0.9.0), in lockstep
  with mof-generation's `environment-chameleon-stream.yml`; bump `MOCHI_TAG` at
  your own risk and re-verify with `tests/smoke_stream_env.py` (the build runs it).
- **LAMMPS libtorch version** — the image compiles `pair_style mace` against
  libtorch **2.5.1** (pre-cxx11 ABI), whereas the native guide
  (`chameleon-stream.md` §1c) uses **2.7.1** cxx11-abi. Both load the same
  `mace-mp0_medium-lammps.pt` and run MD fine; this is an MD-compute detail and
  does **not** affect the streaming layer the benchmark measures.
- **One-time Globus login** — required for `octopus` (above). The other two
  profiles need no credentials.
- **DFT (cp2k) on CPU** — the image installs conda-forge's serial cp2k (pinned
  `*nompi*` → cp2k 2024.2, the newest build that still ships `cp2k.ssmp`; an
  unpinned `conda-forge::cp2k` now resolves to the MPI-only 2026.1 and would
  break the wrapper) plus a `cp2k_shell.ssmp` wrapper (sets `CP2K_DATA_DIR`,
  gives CP2K real OpenMP threads), so the DFT stage **runs** end-to-end on a
  real MOF (energy + forces). Caveat: CPU DFT is *slow* — one MOF's first SCF
  can dominate wall time, and a large structure (every SCF step is costly) or a
  non-converging one (grinds to `max_scf`) can keep a short run from finishing
  its DFT stage. That's a DFT-compute cost, not a transport one. See
  `mof-generation-at-scale/envs/chameleon-stream.md` §3.
- **octopus dual AWS key** — the thinker and server each call
  `GlobusClient.create_key()`, which *rotates* (replaces) the user's single AWS
  MSK key rather than returning a shared one. Both containers still obtain a
  working key and the workflow round-trips, but librdkafka logs persistent
  `SASL … Access denied` churn from whichever key was superseded — noisy but
  non-fatal. A clean fix (mint once on the thinker, hand the creds to the
  server) is future work.
