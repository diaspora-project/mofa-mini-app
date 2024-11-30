ensure_endpoint() {
    endpoint_name=$1
    output=$(proxystore-endpoint list)
    echo "$output"

    # Extract UUID for the given endpoint name
    uuid=$(echo "$output" | grep "^${endpoint_name} " | rev | cut -d " " -f1 | rev)

    if [[ -z $uuid ]]; then
        proxystore-endpoint configure "$endpoint_name"

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

ensure_endpoint my-endpoint