## MOFA Test Pipeline Setup & Execution Guide

---

### 1. Setup Before Running the Workflow

**1.1. Checkout Correct Git Branch**

```bash
cd ~/mof-generation-at-scale
git checkout octopus2
```

**1.2. Verify LAMMPS with MACE Support**

```bash
LD_LIBRARY_PATH=/home/cc/libtorch/lib:$LD_LIBRARY_PATH ./bin/lmp -h | grep mace
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
    lammps_cmd = (
        'LD_LIBRARY_PATH=/home/cc/libtorch/lib:$LD_LIBRARY_PATH /home/cc/lammps/build-mace/bin/lmp',
    )
```

**1.7. Reset `mofa_test2` Kafka Topics**

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

Run reset script:
```bash
source playwright-secrets.sh
python playwright-reset-topic-headless.py
```

---

## 2. Run MOFA Workflow with `OctopusQueues`

### 2.1. Install Dependencies

Install the Kafka client library:

```bash
pip install "diaspora-event-sdk[kafka-python]"
```

### 2.2. Configure Workflow Script

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
  --dft-opt-steps 2
```

### 2.3. Set Queue Backend

In `run_parallel_workflow.py`, import and instantiate `OctopusQueues`:

```python
from mofa.octopus import OctopusQueues

queues = OctopusQueues(
    topics=['generation', 'lammps', 'cp2k', 'training', 'assembly'],
)
```

### 2.4. Set Kafka Credentials

Create `octopus-secrets.sh` in `~/mof-generation-at-scale`:

```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...
```

### 2.5. Reset Kafka Topics

Reset Kafka topics using Playwright:

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py
```

### 2.6. Prepare Yourself

Take a deep breath — you're almost there.

### 2.7. Execute the Workflow

```bash
cd ~/mof-generation-at-scale
source octopus-secrets.sh
./example-parallel-run.sh
```

## 3. Run MOFA Workflow with `ProxyQueues`

### 3.1. Install Dependencies

Install ProxyStore and Kafka dependencies:

```bash
pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
```

### 3.2. Configure Workflow Script

Same as [2.2](#22-configure-workflow-script) — edit `example-parallel-run.sh` accordingly.

### 3.3. Set Queue Backend

In `run_parallel_workflow.py`, import and instantiate `ProxyQueues`:

```python
from mofa.proxyqueue import ProxyQueues

queues = ProxyQueues(
    topics=['generation', 'lammps', 'cp2k', 'training', 'assembly'],
)
```

### 3.4. Set Secrets

- Use the same `octopus-secrets.sh` as in [2.4](#24-set-kafka-credentials).
- Additionally, create `proxystream-secrets.sh` in `~/mofa-mini-app`:

```bash
export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

### 3.5. Reset Kafka Topics

Same as [2.5](#25-reset-kafka-topics).

### 3.6. Start ProxyStore Endpoint

Start and verify the endpoint:

```bash
source ~/mofa-mini-app/proxystream-secrets.sh
source ~/mofa-mini-app/ensure_endpoint.sh
echo $PROXYSTORE_ENDPOINT
```

> **Note:** If the endpoint fails to start, modify `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

### 3.7. Execute the Workflow

Same as [2.7](#27-execute-the-workflow):

```bash
cd ~/mof-generation-at-scale
source octopus-secrets.sh
./example-parallel-run.sh
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


### 5.1. Docker build
```bash
docker build -t octopus2 -f Dockerfile-octopus2 .
docker run -it octopus2
```

Inside the container, check installation status:
```bash
cat /var/log/mofa-install.log
```

```bash
cd ~/mof-generation-at-scale
$MOFA_RUN ./example-parallel-run.sh
```

### 5.2 Docker switch mode

```bash

tmp_file=$(mktemp)
cat <<'EOF' > "$tmp_file"
    queues = ProxyQueues(
        topics=['generation', 'lammps', 'cp2k', 'training', 'assembly'],
    )
EOF

sed -i '111,113d' ~/mof-generation-at-scale/run_parallel_workflow.py
sed -i "110r $tmp_file" ~/mof-generation-at-scale/run_parallel_workflow.py

rm "$tmp_file"


$MOFA_RUN proxystore-endpoint list
$MOFA_RUN source ensure_endpoint.sh 

export PROXYSTORE_ENDPOINT=$(cat proxystore_endpoint_uuid.txt)
echo $PROXYSTORE_ENDPOINT

cd ~/mof-generation-at-scale
$MOFA_RUN ./example-parallel-run.sh

```