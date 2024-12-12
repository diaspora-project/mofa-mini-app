# Developing the MOFA Mini App Before Publishing to GitHub Registry


<!-- vscode-markdown-toc -->
* 1. [Building the Docker image](#BuildingtheDockerimage)
	* 1.1. [Option 1. Building the Docker image from GitHub's `mof-generation-at-scale` repository](#Option1.BuildingtheDockerimagefromGitHubsmof-generation-at-scalerepository)
	* 1.2. [Option 2. Building the Docker image from a local copy of the repository](#Option2.BuildingtheDockerimagefromalocalcopyoftherepository)
* 2. [Setting up environment variables](#Settingupenvironmentvariables)
* 3. [Recreate Topics with the `mofa_test2` Prefix on the Kafka-UI Console](#RecreateTopicswiththemofa_test2PrefixontheKafka-UIConsole)
	* 3.1. [Console Access](#ConsoleAccess)
	* 3.2. [Instructions](#Instructions)
* 4. [3. Running the Docker container(s)](#RunningtheDockercontainers)
	* 4.1. [Option 1. Running Thinker and TaskServer in a single container](#Option1.RunningThinkerandTaskServerinasinglecontainer)
		* 4.1.1. [Starting the container](#Startingthecontainer)
		* 4.1.2. [stopping the container](#stoppingthecontainer)
	* 4.2. [Option 2. Running Thinker and TaskServer in separate containers](#Option2.RunningThinkerandTaskServerinseparatecontainers)
		* 4.2.1. [Starting the services](#Startingtheservices)
		* 4.2.2. [Stopping the services](#Stoppingtheservices)

<!-- vscode-markdown-toc-config
	numbering=true
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->


##  1. <a name='BuildingtheDockerimage'></a>Building the Docker image

###  1.1. <a name='Option1.BuildingtheDockerimagefromGitHubsmof-generation-at-scalerepository'></a>Option 1. Building the Docker image from GitHub's `mof-generation-at-scale` repository

```bash
docker build --no-cache -t mofa-app -f Dockerfile-mofka .
```

> **Note:** The `--no-cache` flag ensures that the image is built from scratch without using any cached layers, ensuring that the latest dependencies are pulled and installed.
> **Note:** Remember to specify `--platform linux/arm64` if running on an ARM device. Currently, this does not work with the base image, however.

###  1.2. <a name='Option2.BuildingtheDockerimagefromalocalcopyoftherepository'></a>Option 2. Building the Docker image from a local copy of the repository

```bash
docker build -f Dockerfile-local --platform linux/amd64 -t mofa-app .
```

> **Note:** Make sure that the `mof-generation-at-scale` folder exists in the current directory before running this command. If you have made local changes, this approach will incorporate those changes into the Docker image.


##  2. <a name='Settingupenvironmentvariables'></a>Setting up environment variables

Create a `.env` file in the same directory as your Dockerfile with the following content (or ask Haochen or Valerie for this file). It is important to note that the contents of this file will differ depending on whether you use *octopus* or *mofka*:

#### Octopus .env file
```env
# .env file
STREAM_ENGINE="octopus"
OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198
PROXYSTORE_GLOBUS_CLIENT_ID=...
PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

Replace `<Your_AWS_Access_Key_ID>`, `<Your_AWS_Secret_Access_Key>`, `<PROXYSTORE_GLOBUS_CLIENT_ID>`, and `<PROXYSTORE_GLOBUS_CLIENT_SECRET>` with your actual AWS and Globus credentials (ask Haochen or Valerie).

#### Mofka .env file
```env
# .env file
STREAM_ENGINE="mofka"
PROXYSTORE_GLOBUS_CLIENT_ID=...
PROXYSTORE_GLOBUS_CLIENT_SECRET=...
MOFKA_GROUPFILE="/mnt/mofa/mofka.json"
MOFKA_PROTOCOL="tcp"
```
> **Note:** `MOFKA_GROUPFILE` location should not have to be changed and this environment option will likely be removed.

##  3. <a name='RecreateTopicswiththemofa_test2PrefixontheKafka-UIConsole'></a>Recreate Topics with the `mofa_test2` Prefix on the Kafka-UI Console (**Octopus execution only**)

This step must be performed **before starting each experiment**.

###  3.1. <a name='ConsoleAccess'></a>Console Access
- **URL**: [Kafka-UI Console](http://100.27.155.7/ui/clusters/diaspora/all-topics?perPage=25&q=mofa_test2)  
- **Login Credentials**: Contact Haochen or Valerie for access.

###  3.2. <a name='Instructions'></a>Instructions
1. Identify all topics prefixed with `mofa_test2` that have a **non-zero "Number of messages"**.
2. For each topic:
   - Click the three-dot menu icon on the right-hand side of the topic.
   - Select **"Recreate Topic"** (second option).
   - Click **"Confirm"** to proceed.


##  4. <a name='RunningtheDockercontainers'></a>3. Running the Docker container(s)
###  4.1. <a name='Option1.RunningThinkerandTaskServerinasinglecontainer'></a>Option 1. Running Thinker and TaskServer in a single container

####  4.1.1. <a name='Startingthecontainer'></a>Starting the container

Use the following command to start the container defined in the `docker-compose-single.yml` file:

```bash
docker-compose -f docker-compose-single.yml up
```
####  4.1.2. <a name='stoppingthecontainer'></a>stopping the container

To stop and remove the running container, execute:

```bash
docker-compose -f docker-compose-single.yml down
```

---

###  4.2. <a name='Option2.RunningThinkerandTaskServerinseparatecontainers'></a>Option 2. Running Thinker and TaskServer in separate containers

####  4.2.1. <a name='Startingtheservices'></a>Starting the services

To run the `Thinker` and `TaskServer` services in separate containers, use the default `docker-compose.yml` file:

```bash
docker-compose up
```

####  4.2.2. <a name='Stoppingtheservices'></a>Stopping the services

To stop and remove all running services, execute:

```bash
docker-compose down
```
