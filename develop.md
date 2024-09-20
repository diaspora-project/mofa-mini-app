# Developing the MOFA Mini App Before Publishing to GitHub Registry

## Building the Docker Image

To build the Docker image, run:

```bash
docker build --platform linux/amd64 -t mofa-app .
```

> **Note:** Use the `--no-cache` option to force a rebuild and avoid using cached layers.

## Running Thinker and TaskServer in One Container

To run both Thinker and TaskServer within a single container, you need to configure the AWS credentials and Kafka bootstrap servers using the `.env` file. The script `run_mini_app.sh` will launch Redis and start the MOFA workflow based on the configurations specified in the script.

### Setting Up Environment Variables

Create a `.env` file in the same directory as your Docker setup with the following content:

```env
# .env file
OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198
```

Replace `<Your_AWS_Access_Key_ID>` and `<Your_AWS_Secret_Access_Key>` with your actual AWS credentials.

### Running the Single Container

To run the Docker container with the environment variables loaded from the `.env` file, use the following command:

```bash
# Run the Docker container using environment variables from the .env file
docker run --platform linux/amd64 --env-file .env mofa-app
```

## Using Docker Compose to Run Thinker and TaskServer in Separate Containers

To simplify running and managing both Thinker and TaskServer services along with Redis, you can use Docker Compose. A `docker-compose.yml` file has been created to streamline this process.

### Setting Up Environment Variables

Ensure your `.env` file (as shown above) is in the same directory as your `docker-compose.yml`. The Docker Compose setup will automatically load these variables when starting the services.

### Running Services with Docker Compose

To start the services defined in your Docker Compose file, use the following command:

```bash
docker compose up
```

### Stopping the Services

To stop all running services, execute:

```bash
docker compose down
```

### Important Notes

- Replace `<Your_AWS_Access_Key_ID>` and `<Your_AWS_Secret_Access_Key>` in the `.env` file with your actual AWS credentials.
- Docker and Docker Compose will automatically use the environment variables from the `.env` file, ensuring consistency between single-container and multi-container setups.
