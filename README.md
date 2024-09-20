# MOFA Mini App

A containerized example application of MOF generation code found [here](https://github.com/globus-labs/mof-generation-at-scale/tree/main).

## How to run:

0. Create your GitHub personal access token, see [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic).

### Docker

#### CPU
1. Pull image from Github Registry
```
echo <personal_access_token> | docker login ghcr.io -u <github_username> --password-stdin
docker pull ghcr.io/diaspora-project/mofa-mini-app:main
docker tag ghcr.io/diaspora-project/mofa-mini-app:main mofa
```
2. Run container to execute application
```
docker run --rm mofa
```

#### GPU
1. Pull image from Github Registry
```
echo <personal_access_token> | docker login ghcr.io -u <github_username> --password-stdin
docker pull ghcr.io/diaspora-project/mofa-mini-app:gpu
docker tag ghcr.io/diaspora-project/mofa-mini-app:gpu mofa-gpu
```
2. Run container to execute application
```
docker run --rm --gpus all mofa-gpu
```

### Apptainer on Polaris (GPU)

To run on Polaris, it is recommended to follow instructions for running Apptainer on Polaris provided [here](https://docs.alcf.anl.gov/polaris/data-science-workflows/containers/containers/).

1. Load Apptainer modules
```
module use /soft/spack/gcc/0.6.1/install/modulefiles/Core
module load apptainer
```
  
2. Build Apptainer image from Github Registry
```
echo <personal_access_token> | apptainer remote login -u <github_username> --password-stdin docker://ghcr.io
export APPTAINER_TMPDIR=/local/scratch # have more space available for building image
apptainer build --fakeroot --force mofa docker://ghcr.io/diaspora-project/mofa-mini-app:gpu
```
3. Clone and cd to the MOFa code
```
git clone https://github.com/globus-labs/mof-generation-at-scale.git
cd mof-generation-at-scale
```

4. Generate required input files in apptainer environment (optional, if files have already been generated)
```
cd input-files/zn-paddle-pillar
apptainer exec mofa /bin/bash
source activate mofa
python assemble_inputs.py
exit
cd ../../
```

5. Run container from mof-generation-at-scale root dir to execute application
```
apptainer run --nv ../mofa
```


## Developing the MOFA Mini App Before Publishing to GitHub Registry

### Building the Docker Image

To build the Docker image, run:

```bash
docker build --platform linux/amd64 -t mofa-app .
```

> **Note:** Use the `--no-cache` option to force a rebuild and avoid using cached layers.

### Running the TaskServer Docker Container

To run the TaskServer container, set the necessary environment variables and execute the `docker run` command:

```bash
# Set launch option for TaskServer
export OCTOPUS_LAUNCH_OPTION=server

# Set AWS credentials and Kafka bootstrap servers
export OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
export OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
export OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198

# Run the Docker container
docker run --platform linux/amd64 \
  -e OCTOPUS_LAUNCH_OPTION \
  -e OCTOPUS_AWS_ACCESS_KEY_ID \
  -e OCTOPUS_AWS_SECRET_ACCESS_KEY \
  -e OCTOPUS_BOOTSTRAP_SERVERS \
  mofa-app
```

### Running the Thinker Docker Container

To run the Thinker container, use the following steps:

```bash
# Set launch option for Thinker
export OCTOPUS_LAUNCH_OPTION=thinker

# Set AWS credentials and Kafka bootstrap servers
export OCTOPUS_AWS_ACCESS_KEY_ID=<Your_AWS_Access_Key_ID>
export OCTOPUS_AWS_SECRET_ACCESS_KEY=<Your_AWS_Secret_Access_Key>
export OCTOPUS_BOOTSTRAP_SERVERS=b-1-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198,b-2-public.diaspora.fy49oq.c9.kafka.us-east-1.amazonaws.com:9198

# Run the Docker container
docker run --platform linux/amd64 \
  -e OCTOPUS_LAUNCH_OPTION \
  -e OCTOPUS_AWS_ACCESS_KEY_ID \
  -e OCTOPUS_AWS_SECRET_ACCESS_KEY \
  -e OCTOPUS_BOOTSTRAP_SERVERS \
  mofa-app
```

> **Note:** Replace `<Your_AWS_Access_Key_ID>` and `<Your_AWS_Secret_Access_Key>` with your actual AWS credentials.
