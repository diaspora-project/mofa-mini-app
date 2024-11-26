#!/bin/bash

LAUNCH_OPTION=""

if [ "$OCTOPUS_LAUNCH_OPTION" == "thinker" ]; then
    LAUNCH_OPTION="thinker"
elif [ "$OCTOPUS_LAUNCH_OPTION" == "server" ]; then
    LAUNCH_OPTION="server"
else
    LAUNCH_OPTION="both"
fi

configure_endpoint() {
    # Get current Unix timestamp (compatible with both macOS and Linux)
    local timestamp
    if [[ "$OSTYPE" == "darwin"* ]]; then
        timestamp=$(date -u +%s)  # macOS
    else
        timestamp=$(date +%s)    # Linux
    fi

    # Create endpoint name with timestamp
    local endpoint_name="${1}-${timestamp}"
    # echo $endpoint_name
    
    # Configure the endpoint
    local output
    output=$(proxystore-endpoint configure "$endpoint_name")
    echo "$output"
    
    # Extract the UUID using grep and tr
    local uuid
    uuid=$(echo "$output" | grep -o '<[a-f0-9-]*>' | tr -d '<>')

    if [[ -n $uuid ]]; then
        export PROXYSTORE_ENDPOINT=$uuid
        echo "Environment variable PROXYSTORE_ENDPOINT set to $uuid"
    else
        echo "Failed to extract UUID."
    fi

    # Start the configured endpoint
    proxystore-endpoint start "$endpoint_name"
    proxystore-endpoint list
    sleep 20
    cat /root/.local/share/proxystore/$endpoint_name/log.txt
}

# actual endpoint name: my-endpoint-timestamp
configure_endpoint my-endpoint


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
