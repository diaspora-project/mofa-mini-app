# Developing the MOFA Mini App Before Publishing to GitHub Registry

## Building the Docker Image

### Option 1. Building the Docker Image from GitHub

```bash
docker build --platform linux/amd64 --no-cache -t mofa-app .
```

> **Note:** The `--no-cache` flag ensures that the image is built from scratch without using any cached layers, ensuring that the latest dependencies are pulled and installed.

### Option 2. Building the Docker Image from a Local Copy

```bash
docker build -f Dockerfile-local --platform linux/amd64 -t mofa-app .
```

> **Note:** Make sure that the `mof-generation-at-scale` folder exists in the current directory before running this command. If you have made local changes, this approach will incorporate those changes into the Docker image.


## Setting Up Environment Variables

Create a `.env` file in the same directory as your Docker setup with the following content:

```env
# .env file
OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198
```

Replace `<Your_AWS_Access_Key_ID>` and `<Your_AWS_Secret_Access_Key>` with your actual AWS credentials.

## Option 1. Running Thinker and TaskServer in the Single Container

### Starting the Container

Use the following command to start the container defined in the `docker-compose-single.yml` file:

```bash
docker-compose -f docker-compose-single.yml up
```
### Stopping the Container

To stop and remove the running container, execute:

```bash
docker-compose -f docker-compose-single.yml down
```

---

## Option 2. Running Thinker and TaskServer in Separate Containers

### Starting the Services

To run the `Thinker` and `TaskServer` services in separate containers, use the default `docker-compose.yml` file:

```bash
docker-compose up
```

### Stopping the Services

To stop and remove all running services, execute:

```bash
docker-compose down
```
