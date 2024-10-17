# Developing the MOFA Mini App Before Publishing to GitHub Registry


<!-- vscode-markdown-toc -->
* 1. [Building the docker image](#Buildingthedockerimage)
	* 1.1. [Option 1. Building the docker image from GitHub's `mof-generation-at-scale` repository](#Option1.BuildingthedockerimagefromGitHubsmof-generation-at-scalerepository)
	* 1.2. [Option 2. Building the Docker Image from a local copy of the repository](#Option2.BuildingtheDockerImagefromalocalcopyoftherepository)
* 2. [Setting up environment variables](#Settingupenvironmentvariables)
* 3. [3. Running the docker container(s)](#Runningthedockercontainers)
	* 3.1. [Option 1. Running Thinker and TaskServer in a single container](#Option1.RunningThinkerandTaskServerinasinglecontainer)
		* 3.1.1. [Starting the container](#Startingthecontainer)
		* 3.1.2. [stopping the container](#stoppingthecontainer)
	* 3.2. [Option 2. Running Thinker and TaskServer in separate containers](#Option2.RunningThinkerandTaskServerinseparatecontainers)
		* 3.2.1. [Starting the services](#Startingtheservices)
		* 3.2.2. [Stopping the services](#Stoppingtheservices)

<!-- vscode-markdown-toc-config
	numbering=true
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->


##  1. <a name='Buildingthedockerimage'></a>Building the Docker image

###  1.1. <a name='Option1.BuildingthedockerimagefromGitHubsmof-generation-at-scalerepository'></a>Option 1. Building the Docker image from GitHub's `mof-generation-at-scale` repository

```bash
docker build --platform linux/amd64 --no-cache -t mofa-app .
```

> **Note:** The `--no-cache` flag ensures that the image is built from scratch without using any cached layers, ensuring that the latest dependencies are pulled and installed.

###  1.2. <a name='Option2.BuildingtheDockerImagefromalocalcopyoftherepository'></a>Option 2. Building the Docker image from a local copy of the repository

```bash
docker build -f Dockerfile-local --platform linux/amd64 -t mofa-app .
```

> **Note:** Make sure that the `mof-generation-at-scale` folder exists in the current directory before running this command. If you have made local changes, this approach will incorporate those changes into the Docker image.


##  2. <a name='Settingupenvironmentvariables'></a>Setting up environment variables

Create a `.env` file in the same directory as your Dockerfile with the following content:

```env
# .env file
OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198
```

Replace `<Your_AWS_Access_Key_ID>` and `<Your_AWS_Secret_Access_Key>` with your actual AWS credentials (ask Haochen or Valerie).

##  3. <a name='Runningthedockercontainers'></a>3. Running the Docker container(s)
###  3.1. <a name='Option1.RunningThinkerandTaskServerinasinglecontainer'></a>Option 1. Running Thinker and TaskServer in a single container

####  3.1.1. <a name='Startingthecontainer'></a>Starting the container

Use the following command to start the container defined in the `docker-compose-single.yml` file:

```bash
docker-compose -f docker-compose-single.yml up
```
####  3.1.2. <a name='stoppingthecontainer'></a>stopping the container

To stop and remove the running container, execute:

```bash
docker-compose -f docker-compose-single.yml down
```

---

###  3.2. <a name='Option2.RunningThinkerandTaskServerinseparatecontainers'></a>Option 2. Running Thinker and TaskServer in separate containers

####  3.2.1. <a name='Startingtheservices'></a>Starting the services

To run the `Thinker` and `TaskServer` services in separate containers, use the default `docker-compose.yml` file:

```bash
docker-compose up
```

####  3.2.2. <a name='Stoppingtheservices'></a>Stopping the services

To stop and remove all running services, execute:

```bash
docker-compose down
```
