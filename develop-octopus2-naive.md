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

Install dependencies (only once):
```bash
pip install playwright
playwright install-deps
playwright install chromium
```

Create `playwright-secrets.sh`:
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

### 2. Run Example MOFA Workflow

**2.1. Set Up Kafka Dependencies and Secrets**

Install dependencies (only once):
```bash
pip install "diaspora-event-sdk[kafka-python]"
```

Create `octopus-secrets.sh`:
```bash
export OCTOPUS_AWS_ACCESS_KEY_ID=...
export OCTOPUS_AWS_SECRET_ACCESS_KEY=...
export OCTOPUS_BOOTSTRAP_SERVERS=...
```

**2.2. Configure Workflow Script**

Edit `~/mof-generation-at-scale/example-parallel-run.sh`:

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

**2.3. Run the Workflow**

```bash
source octopus-secrets.sh
./example-parallel-run.sh
```