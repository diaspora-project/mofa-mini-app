## MOFA Test Pipeline Setup & Execution Guide

---

### 1. Setup Before Running the Workflow

**1.1. Checkout Correct Git Branch and Install Dependencies**

```bash
cd ~/mof-generation-at-scale
git checkout octopus2
```

Install the Kafka client library:

```bash
pip install "diaspora-event-sdk[kafka-python]"
pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
```

**1.2. Verify LAMMPS with MACE Support**

```bash
LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ./bin/lmp -h | grep mace
```

**1.3. Prepare Input Files**

```bash
cd ~/mof-generation-at-scale/input-files/zn-paddle-pillar
python assemble_inputs.py
```

**1.4. Download MACE Model**

```bash
cd ~/mof-generation-at-scale/input-files/mace
./get-macemp-0a.sh
```

**1.5. Start Redis**

```bash
redis-server --daemonize yes
```

**1.6. Use `LocalConfig` for Local Testing**

Edit `~/mof-generation-at-scale/mofa/hpc/config.py`:

```python
class LocalConfig(HPCConfig):
    """Single-worker config for testing."""
    torch_device = 'cpu'
    lammps_env = {}
    lammps_cmd = ( 'LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ~/lammps/build-mace/bin/lmp', )
```

**1.7. Set Octopus and ProxyStream Credentials**

Create `secrets.sh` in `~/mof-generation-at-scale`:

```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...

export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

**1.8. Configure Workflow Script**

Edit `example-parallel-run.sh` in `~/mof-generation-at-scale`:

```bash
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
  --redis-host 127.0.0.1 \
  --compute-config "local" \
  --mace-model-path ./input-files/mace/mace-mp0_medium-lammps.pt \
  --md-timesteps 1000 \
  --dft-opt-steps 2 \
  --launch-option $LAUNCH_OPTION \
  --queue-type $QUEUE_TYPE
```

**1.9. Reset `mofa_test2` Kafka Topics**

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

**1.10. Test Run MOFA Workflow with `RedisQueues`**

Test Launch Thinker and Server

```bash
cd ~/mof-generation-at-scale
LAUNCH_OPTION=both QUEUE_TYPE=redis ./example-parallel-run.sh
```

---

## 2. Run MOFA Workflow with `OctopusQueues`

### 2.1. Reset Kafka Topics

Use Playwright to clear existing Kafka topics:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```

### 2.2. Launch Thinker and Server

Use two separate terminals to run the workflow.

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

> Ensure both terminals use the same environment and configuration settings.

---

## 3. Run MOFA Workflow with `ProxyQueues`

### 3.1. Reset Kafka Topics

Reset topics again before switching to `ProxyQueues`:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```

### 3.2. Start the ProxyStore Endpoint

Initialize the ProxyStore endpoint and export the ID **in two terminals**:

```bash
source ~/mofa-mini-app/proxystream-secrets.sh
source ~/mofa-mini-app/ensure_endpoint.sh
echo $PROXYSTORE_ENDPOINT
```

> **Note:** If the endpoint fails to initialize, try modifying `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

### 3.3. Launch Thinker and Server

**Terminal 1: Launch Thinker**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=thinker QUEUE_TYPE=proxystream ./example-parallel-run.sh
```

**Terminal 2: Launch Server**

```bash
cd ~/mof-generation-at-scale
source secrets.sh
LAUNCH_OPTION=server QUEUE_TYPE=proxystream ./example-parallel-run.sh
```

---

### 4. Troubleshooting MongoDB Errors

If you see MongoDB errors during execution:
```bash
sudo systemctl stop mongod
sudo rm -rf /var/lib/mongodb/*
sudo systemctl start mongod
sudo systemctl status mongod
```

### 5.1
```bash
docker compose up -d
docker exec -it octopus2 bash
echo $LAUNCH_OPTION
echo $QUEUE_TYPE
 cd ~/mof-generation-at-scale/
conda run -n mofa ./example-parallel-run.sh 
```


### 5.3. Debug Docker Build and Run

Build the container and run it with secrets injected from an `.env` file:
```bash

docker compose up -d
docker build -t octopus2 -f Dockerfile-octopus2 .
docker run --env-file=secrets.env -it octopus2
```

Once inside the container, verify environment setup and installation log:
```bash
echo $OCTOPUS_BOOTSTRAP_SERVERS
cat /var/log/mofa-install.log
```

You should already be inside the `mofa` conda environment. To start the MOFA workflow:
```bash
cd ~/mof-generation-at-scale
./example-parallel-run.sh
```

### 5.2. Switch to `ProxyQueues` Mode

Set up the ProxyStore endpoint:
```bash
source ~/ensure_endpoint.sh 
echo $PROXYSTORE_ENDPOINT
```

Then run the MOFA workflow:

```bash
cd ~/mof-generation-at-scale
$MOFA_RUN ./example-parallel-run.sh

```