## MOFA Test Pipeline Setup & Execution Guide

---

### 1. Additional Setup (Before Running the Workflow)

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
cd /home/cc/mof-generation-at-scale/input-files/zn-paddle-pillar
python assemble_inputs.py
```

**1.4. Download MACE Model**

```bash
cd /home/cc/mof-generation-at-scale/input-files/mace
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

### 2. Run MOFA Workflow with `OctopusQueues`

**2.1. Set Kafka Credentials**

Install dependencies:
```bash
pip install "diaspora-event-sdk[kafka-python]"
```

Create `octopus-secrets.sh` in `~/mof-generation-at-scale`:
```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...
```

**2.2. Configure Workflow Script**

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

**2.3. Execute the Workflow**

```bash
source octopus-secrets.sh
./example-parallel-run.sh
```

---

### 3. Run MOFA Workflow with `ProxyQueues`

**3.1. Install and Configure ProxyStore**

```bash
pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
```

Create `proxystream-secrets.sh` in `~/mofa-mini-app`:
```bash
export PROXYSTORE_GLOBUS_CLIENT_ID=...
export PROXYSTORE_GLOBUS_CLIENT_SECRET=...
```

Start and verify ProxyStore endpoint:
```bash
source ~/mofa-mini-app/proxystream-secrets.sh
source ~/mofa-mini-app/ensure_endpoint.sh
echo $PROXYSTORE_ENDPOINT
```

> If endpoint fails to start, update `proxystore-endpoint configure` in `ensure_endpoint.sh` to use `--use-fqdn` instead of `--use-ip`.

**3.2. Reset Kafka Topics and Run Workflow**

```bash
source ~/mofa-mini-app/playwright-secrets.sh
python ~/mofa-mini-app/playwright-reset-topic-headless.py

cd ~/mofa-mini-app
source octopus-secrets.sh
./example-parallel-run.sh
```

**3.3. Troubleshooting MongoDB Errors**

If you see MongoDB errors during execution:
```bash
sudo systemctl stop mongod
sudo rm -rf /var/lib/mongodb/*
sudo systemctl start mongod
sudo systemctl status mongod
```