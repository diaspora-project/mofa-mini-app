# MOFA - Diaspora Mini App

[Codebase](https://github.com/globus-labs/mof-generation-at-scale/tree/octopus2), based on [mof-generation-at-scale/0728896](https://github.com/globus-labs/mof-generation-at-scale/tree/07288963835b5dbea7ccf52f09ecbd4433bf3177)

[Octopus Web Console](http://184.73.61.163/ui/clusters/diaspora/all-topics?perPage=25&q=test2)


## 1. Usage Guide

1. Create a `secrets.env` file in this directory (along with `Dockerfile`):
```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...

export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

2. **Reset Kafka Topics**: See Section 1.9 and 2.1 for instructions on resetting Octopus topics before each run.

3. **Run with OctopusQueues**: Make sure `QUEUE_TYPE=octopus` (default) is used in the Docker Compose file:
   ```bash
   docker compose build
   docker compose up
   ```

4. **Run with ProxyQueues**: Update the `docker-compose.yml` by changing both instances of `QUEUE_TYPE=octopus` to `QUEUE_TYPE=proxystream`. Then, run `docker compose up`

5. **Known Issues (To Be Fixed)**
- When running in split mode (separate thinker and server), each process opens its own local MongoDB instance.

## 2. Develop Guide (working with the MOFA codebase outside docker)

### 2.1. Setup

**2.1.1. Checkout Correct Git Branch and Install Dependencies**

```bash
cd ~/mof-generation-at-scale
git checkout octopus2
```

Install the Kafka client library:

```bash
pip install "diaspora-event-sdk[kafka-python]"
pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
```

**2.1.2. Verify LAMMPS with MACE Support**

```bash
LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ./bin/lmp -h | grep mace
```

**2.1.3. Prepare Input Files**

```bash
cd ~/mof-generation-at-scale/input-files/zn-paddle-pillar
python assemble_inputs.py
```

**2.1.4. Download MACE Model**

```bash
cd ~/mof-generation-at-scale/input-files/mace
./get-macemp-0a.sh
```

**2.1.5. Start Redis**

```bash
redis-server --daemonize yes
```

**2.1.6. Use `LocalConfig` for Local Testing**

Edit `~/mof-generation-at-scale/mofa/hpc/config.py`:

```python
class LocalConfig(HPCConfig):
    """Single-worker config for testing."""
    torch_device = 'cpu'
    lammps_env = {}
    lammps_cmd = ( 'LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ~/lammps/build-mace/bin/lmp', )
```

**2.1.7. Set Octopus and ProxyStream Credentials**

Create `secrets.sh` in `~/mof-generation-at-scale`:

```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...

export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

**2.1.8. Configure Workflow Script**

Edit `example-parallel-run.sh` in `~/mof-generation-at-scale`:

```bash
#! /bin/bash

: "${LAUNCH_OPTION:=both}"
: "${QUEUE_TYPE:=redis}"
: "${REDIS_HOST:=127.0.0.1}"
: "${PROXYSTORE_ENDPOINT_NAME:=ep8765}"
: "${PROXYSTORE_ENDPOINT_PORT:=8765}"

source ensure_endpoint.sh $PROXYSTORE_ENDPOINT_NAME $PROXYSTORE_ENDPOINT_PORT

echo $PROXYSTORE_ENDPOINT

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
      --queue-type $QUEUE_TYPE

```

**2.1.9. Reset `mofa_test2` Kafka Topics**

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

**2.1.10. Test Run MOFA Workflow with `RedisQueues`**

Test Launch Thinker and Server

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=both QUEUE_TYPE=redis ./example-parallel-run.sh
```

Use two separate terminals to run the workflow.
> **Note:** If the endpoint fails to initialize, try modifying `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

---

## 2.2. Run MOFA Workflow with `OctopusQueues`

### 2.2.1. Reset Kafka Topics

Use Playwright to clear existing Kafka topics:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```

### 2.2.2. Launch Thinker and Server

Use two separate terminals to run the workflow.
> **Note:** If the endpoint fails to initialize, try modifying `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

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

---

## 2.3. Run MOFA Workflow with `ProxyQueues`

### 2.3.1. Reset Kafka Topics

Reset topics again before switching to `ProxyQueues`:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```

### 2.3.2. Launch Thinker and Server

> **Note:** If the endpoint fails to initialize, try modifying `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

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

---

## 4. Troubleshooting Errors

If you see MongoDB errors during execution:
```bash
sudo systemctl stop mongod
sudo rm -rf /var/lib/mongodb/*
sudo systemctl start mongod
sudo systemctl status mongod
```

### 4.1 Troubleshooting Docker errors
```bash
docker compose build
docker compose up 
# OR
docker compose up -d
docker exec -it mofa bash
echo $LAUNCH_OPTION
echo $QUEUE_TYPE
docker compose down
# scratch
docker compose up -d
docker build -t octopus2 -f Dockerfile .
docker run --env-file=secrets.env -it octopus2
# scratch
echo $OCTOPUS_BOOTSTRAP_SERVERS
cat /var/log/mofa-install.log

```

### 4.2. Docker Image Structure

```bash
├── root/
│   ├── mof-generation-at-scale/
│   │   ├── example-parallel-run.sh          # Entry script for running the MOFA workflow
│   │   ├── ensure_endpoint.sh               # Script to ensure ProxyStore endpoint
│   │   └── mofa/
│   │       └── hpc/
│   │           └── config.py                # Config file modified for local CPU LAMMPS
│   ├── libtorch/                            # Extracted PyTorch C++ distribution
│   └── lammps/                              # LAMMPS source and build directory
```