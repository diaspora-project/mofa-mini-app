# MOFA - Diaspora Mini App

## 1. Overview

[MOFA Codebase](https://github.com/globus-labs/mof-generation-at-scale/tree/octopus2), based on [mof-generation-at-scale/0728896](https://github.com/globus-labs/mof-generation-at-scale/tree/07288963835b5dbea7ccf52f09ecbd4433bf3177)

[Octopus Web Console](http://184.73.61.163/ui/clusters/diaspora/all-topics?perPage=25&q=test2)


## 2. Docker Usage Guide

### 2.1. Prerequisites

- Docker and Docker Compose installed
- `secrets.env` file with required credentials (see below)

### 2.2. Setup `secrets.env`
```bash
OCTOPUS_AWS_ACCESS_KEY_ID=...
OCTOPUS_AWS_SECRET_ACCESS_KEY=...
OCTOPUS_BOOTSTRAP_SERVERS=...
PROXYSTORE_GLOBUS_CLIENT_ID=...
PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

### 2.3. Reset Kafka Topics

See Section 2.1.10 for instructions on resetting Octopus topics **before each run**.

### 2.4. Run with OctopusQueues

Make sure `QUEUE_TYPE=octopus` (default) is used in the Docker Compose file, then run
```bash
docker compose build
docker compose up
```

### 2.5. Run with ProxyQueues

Edit `docker-compose.yml`: set `QUEUE_TYPE=proxystream` for both services, then run `docker compose up`.

## 3. Local Development & Troubleshooting

### 3.1. Prerequisites

**3.1.1. Checkout Correct Git Branch and Install Dependencies**

```bash
cd ~/mof-generation-at-scale
git checkout octopus2
```

See MOFA's `README.md` and this repo's `prereq.sh` for detials.

**3.1.2. Install the Kafka client library**

```bash
pip install "diaspora-event-sdk[kafka-python]"
pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
```

**3.1.3. Verify LAMMPS with MACE Support**

```bash
LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ./bin/lmp -h | grep mace
```

**3.1.4. Prepare Input Files**

```bash
cd ~/mof-generation-at-scale/input-files/zn-paddle-pillar
python assemble_inputs.py
```

**3.1.5. Download MACE Model**

```bash
cd ~/mof-generation-at-scale/input-files/mace
./get-macemp-0a.sh
```

**3.1.6. Start Redis**

```bash
redis-server --daemonize yes
```

MongoDB will be started by the thinker.

**3.1.7. Update `LocalConfig` for Local Testing**

Edit `~/mof-generation-at-scale/mofa/hpc/config.py`:

```python
class LocalConfig(HPCConfig):
    """Single-worker config for testing."""
    torch_device = 'cpu'
    lammps_env = {}
    lammps_cmd = ( 'LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ~/lammps/build-mace/bin/lmp', )
```

**3.1.8. Set Octopus and ProxyStream Credentials**

Create `secrets.sh` in `~/mof-generation-at-scale`:

```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...

export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

**3.1.9. Copy `ensure_endpoint.sh` to `~/mof-generation-at-scale`**

Also make the shell script executable: `chmod +x ~/mof-generation-at-scale/ensure_endpoint.sh`

**3.1.10. Configure Workflow Script**

Edit `example-parallel-run.sh` in `~/mof-generation-at-scale`:

```bash
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

```

### 3.2. Run WOFA Workflow

#### 3.2.1. Run MOFA Workflow with `RedisQueues`

Test Launch Thinker and Server

```bash
cd ~/mof-generation-at-scale
source secrets.sh
./example-parallel-run.sh
# OR
LAUNCH_OPTION=both QUEUE_TYPE=redis ./example-parallel-run.sh
```

#### 3.2.2. Reset `mofa_test2` Kafka Topics

In a separate virtual environemnt from `mofa` (due to dependency conflicts), install:
```bash
pip install playwright
playwright install-deps
playwright install chromium
```

Create `playwright-secrets.sh` in `~/mofa-mini-app`:
```bash
export TOPIC_USERNAME="your_username"
export TOPIC_PASSWORD="your_password"
export TOPIC_BASE_URL="http://kafbat-url"
```

Use Playwright to reset existing Kafka topics:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```


#### 3.2.3. Run MOFA Workflow with `OctopusQueues`

**3.2.3.1. Run both thinker and server**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=thinker QUEUE_TYPE=octopus ./example-parallel-run.sh
```

**3.2.3.2. Run thinker and server separately**

**Terminal 1: Launch Thinker**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=thinker QUEUE_TYPE=octopus ./example-parallel-run.sh
```

**Terminal 2: Launch Server**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=server QUEUE_TYPE=octopus ./example-parallel-run.sh
```

#### 3.2.4. Run MOFA Workflow with `ProxyQueues`

**3.2.4.1. Run both thinker and server**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=thinker QUEUE_TYPE=proxystream ./example-parallel-run.sh
```

**3.2.4.2. Run thinker and server separately**

**Terminal 1: Launch Thinker**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=thinker QUEUE_TYPE=proxystream ./example-parallel-run.sh
# OR
LAUNCH_OPTION=thinker QUEUE_TYPE=proxystream PROXYSTORE_ENDPOINT_NAME=ep8766 PROXYSTORE_ENDPOINT_PORT=8766 ./example-parallel-run.sh
```

**Terminal 2: Launch Server**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=server QUEUE_TYPE=proxystream ./example-parallel-run.sh
# OR
LAUNCH_OPTION=server QUEUE_TYPE=proxystream PROXYSTORE_ENDPOINT_NAME=ep8767 PROXYSTORE_ENDPOINT_PORT=8767 ./example-parallel-run.sh
```

> **Note:** If the endpoint fails to initialize, try modifying `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

## 4. Troubleshooting Errors

### 4.1. Develop Modes and Parameters Summary

| Mode                | QUEUE_TYPE      | LAUNCH_OPTION                | Required Parameters                        | Notes                                 |
|---------------------|-----------------|------------------------------|--------------------------------------------|---------------------------------------|
| RedisQueues         | redis           | both                         | REDIS_HOST, MONGO_HOST                     | Only `both` supported                 |
| OctopusQueues       | octopus         | both / thinker / server      | REDIS_HOST, MONGO_HOST                     | Split or combined mode                |
| ProxyQueues         | proxystream     | both / thinker / server      | PROXYSTORE_ENDPOINT_NAME, PROXYSTORE_ENDPOINT_PORT, MONGO_HOST | REDIS_HOST not used                   |


### 4.2. Troubleshooting Docker errors
```bash
docker compose build
docker compose up 
# OR
docker compose up -d
docker exec -it thinker bash
echo $LAUNCH_OPTION  $QUEUE_TYPE
docker compose down
# OR
docker build -t octopus2 -f Dockerfile .
docker run --env-file=secrets.env -it octopus2
```

### 4.3. Docker Image Structure

```bash
├── root/
│   ├── mof-generation-at-scale/
│   │   ├── example-parallel-run.sh          # Entry script for running the MOFA workflow
│   │   ├── ensure_endpoint.sh               # Script to ensure ProxyStore endpoint
│   │   └── mofa/
│   │       └── hpc/
│   │           └── config.py                
│   ├── libtorch/                            
│   └── lammps/                              
```