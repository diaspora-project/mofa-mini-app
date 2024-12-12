#!/bin/bash

LAUNCH_OPTION=""

if [ "$OCTOPUS_LAUNCH_OPTION" == "thinker" ]; then
    LAUNCH_OPTION="thinker"
elif [ "$OCTOPUS_LAUNCH_OPTION" == "server" ]; then
    LAUNCH_OPTION="server"
else
    LAUNCH_OPTION="both"
fi

ensure_endpoint() {
    endpoint_name=$1
    endpoint_port=${2:-8765}

    output=$(proxystore-endpoint list)
    echo "$output"

    # Extract UUID for the given endpoint name
    uuid=$(echo "$output" | grep "^${endpoint_name} " | rev | cut -d " " -f1 | rev)

    if [[ -z $uuid ]]; then
        proxystore-endpoint configure "$endpoint_name" --port $endpoint_port

        output=$(proxystore-endpoint list)
        echo "$output"
        uuid=$(echo "$output" | grep "^${endpoint_name} " | rev | cut -d " " -f1 | rev)
    fi

    if [[ -n $uuid ]]; then
        export PROXYSTORE_ENDPOINT=$uuid
        echo "PROXYSTORE_ENDPOINT is set to: $PROXYSTORE_ENDPOINT"
    else
        echo "Failed to configure or find endpoint: $endpoint_name"
        return 1
    fi

    proxystore-endpoint start "$endpoint_name"  # idempotent operation
    sleep 1

    log_file="$HOME/.local/share/proxystore/$endpoint_name/log.txt"

    while true; do
        if cat "$log_file" | grep -q "Uvicorn running on http://"; then
            echo "Detected 'Uvicorn running on http://'. Proceed to mini app."
            break
        else
            echo "$(date): Waiting for Uvicorn to start. Retrying in 5 seconds..."
            tail -n 1 "$log_file"
            sleep 5
        fi
    done

    # echo "Endpoint log:"
    # cat "$log_file"
}

ensure_endpoint my-endpoint $PROXYSTORE_ENDPOINT_PORT
if [ ${STREAM_ENGINE} = "mofka" ]
then
    export LD_LIBRARY_PATH="$(find /home/runner/work/  -type d -name "lib" -print | tr '\n' ':'q):${LD_LIBRARY_PATH}"
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
      --dft-opt-steps 0 \
      --compute-config local \
      --launch-option $LAUNCH_OPTION
