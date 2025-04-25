#! /bin/bash

: "${LAUNCH_OPTION:=both}"
: "${QUEUE_TYPE:=redis}"
: "${REDIS_HOST:=127.0.0.1}"
: "${MONGO_HOST:=localhost}"
: "${PROXYSTORE_ENDPOINT_NAME:=ep8765}"
: "${PROXYSTORE_ENDPOINT_PORT:=8765}"

echo "LAUNCH_OPTION:             $LAUNCH_OPTION"
echo "QUEUE_TYPE:                $QUEUE_TYPE"
echo "REDIS_HOST:                $REDIS_HOST"
echo "MONGO_HOST:                $MONGO_HOST"
echo "PROXYSTORE_ENDPOINT_NAME:  $PROXYSTORE_ENDPOINT_NAME"
echo "PROXYSTORE_ENDPOINT_PORT:  $PROXYSTORE_ENDPOINT_PORT"

if [[ "$QUEUE_TYPE" == "proxystream" ]]; then
    source ensure_endpoint.sh $PROXYSTORE_ENDPOINT_NAME $PROXYSTORE_ENDPOINT_PORT
    echo "PROXYSTORE_ENDPOINT:       $PROXYSTORE_ENDPOINT"
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
      --redis-host $REDIS_HOST \
      --compute-config "local" \
      --mace-model-path ./input-files/mace/mace-mp0_medium-lammps.pt \
      --md-timesteps 1000 \
      --dft-opt-steps 2 \
      --launch-option $LAUNCH_OPTION \
      --queue-type $QUEUE_TYPE \
      --mongo-host $MONGO_HOST