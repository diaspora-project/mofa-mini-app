#!/bin/bash

redis-server --daemonize yes

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
      --redis-host 127.0.0.1 \
      --dft-opt-steps 0 \
      --compute-config local

#python run_serial_workflow.py \
#      --node-path input-files/zn-paddle-pillar/node.json \
#      --generator-path input-files/zn-paddle-pillar/geom_difflinker.ckpt \
#      --ligand-templates input-files/zn-paddle-pillar/template_*_prompt.yml \
#      --num-samples 64 \
#      --num-to-assemble 4 \
#      --torch-device cpu
