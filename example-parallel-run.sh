#! /bin/bash

: "${LAUNCH_OPTION:=both}"
: "${QUEUE_TYPE:=redis}"
: "${REDIS_HOST:=127.0.0.1}"

python run_parallel_workflow.py \
      --node-path input-files/zn-paddle-pillar/node.json \
      --generator-path models/geom-300k/geom_difflinker_epoch=997_new.ckpt \
      --generator-config-path models/geom-300k/config-tf32-a100.yaml \
      --ligand-templates input-files/zn-paddle-pillar/template_*_prompt.yml \
      --retrain-freq 2 \
      --num-epochs 4 \
      --num-samples 8 \
      --gen-batch-size 64 \
      --simulation-budget 4 \
      --redis-host $REDIS_HOST \
      --compute-config "local" \
      --mace-model-path ./input-files/mace/mace-mp0_medium-lammps.pt \
      --md-timesteps 1000 \
      --dft-opt-steps 2 \
      --launch-option $LAUNCH_OPTION \
      --queue-type $QUEUE_TYPE
