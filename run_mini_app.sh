#!/bin/bash

LAUNCH_OPTION=""

if [ "$OCTOPUS_LAUNCH_OPTION" == "thinker" ]; then
    LAUNCH_OPTION="thinker"
elif [ "$OCTOPUS_LAUNCH_OPTION" == "server" ]; then
    LAUNCH_OPTION="server"
else
    LAUNCH_OPTION="both"
fi

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
      --redis-host redis-service \
      --dft-opt-steps 0 \
      --compute-config local \
      --launch-option $LAUNCH_OPTION
