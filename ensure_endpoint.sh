# ensure_endpoint NAME [PORT]
# Ensures a ProxyStore endpoint with the given name exists and is running.
ensure_endpoint() {
    endpoint_name=$1
    endpoint_port=${2:-8765}  # Default port is 8765 if not provided

    # Check if the endpoint already exists
    output=$(proxystore-endpoint list)
    echo "$output"

    # Extract UUID for the given endpoint name
    uuid=$(echo "$output" | awk -v name="$endpoint_name" '$1 == name { print $NF }')

    # If UUID not found, configure the endpoint
    if [[ -z $uuid ]]; then
        echo "Endpoint '$endpoint_name' not found. Creating..."
        proxystore-endpoint configure "$endpoint_name" --port "$endpoint_port" --use-ip

        # Re-check after configuration
        output=$(proxystore-endpoint list)
        echo "$output"
        uuid=$(echo "$output" | awk -v name="$endpoint_name" '$1 == name { print $NF }')
    fi

    # If still no UUID, exit with error
    if [[ -z $uuid ]]; then
        echo "Failed to configure or find endpoint: $endpoint_name"
        return 1
    fi

    # Export environment variable so other tools can use the endpoint
    export PROXYSTORE_ENDPOINT="$uuid"
    echo "$uuid" > proxystore_endpoint_uuid.txt
    echo "PROXYSTORE_ENDPOINT is set to: $PROXYSTORE_ENDPOINT"

    # Start the endpoint (idempotent)
    proxystore-endpoint start "$endpoint_name"
    sleep 1

    log_file="$HOME/.local/share/proxystore/$endpoint_name/log.txt"

    # Wait until the endpoint log shows Uvicorn is running
    while ! grep -q "Uvicorn running on http://" "$log_file"; do
        echo "$(date): Waiting for Uvicorn to start. Retrying in 5 seconds..."
        tail -n 1 "$log_file"
        sleep 5
    done

    echo "Uvicorn is running. Endpoint log:"
    cat "$log_file"
}

# Call the function with name and optionally port
ensure_endpoint my-endpoint "$PROXYSTORE_ENDPOINT_PORT"
