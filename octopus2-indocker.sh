# Suppress interactive apt prompts
export DEBIAN_FRONTEND=noninteractive

# Install required system packages
apt-get update && apt-get upgrade -y
apt-get install -y wget git vim curl gnupg libxrender1 \
                   libopenmpi-dev openmpi-bin \
                   intel-mkl intel-mkl-full libmkl-dev \
                   unzip cmake \
                   python3.10 python3.10-venv python3.10-dev

# Install Miniconda silently
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p /opt/conda
export PATH=/opt/conda/bin:$PATH

MOFA_RUN="conda run -n mofa"

# Clone and checkout MOFA repository
cd /root # this is needed because the initial directory is the root directory (/)
git clone https://github.com/globus-labs/mof-generation-at-scale.git
cd mof-generation-at-scale/
git checkout octopus2
# mv /root/example-parallel-run.sh /root/mof-generation-at-scale/

# Setup conda environment
conda update -n base -y conda
conda install -n base -y conda-libmamba-solver
conda config --set solver libmamba
conda env create --file envs/environment-cpu.yml

# Install Redis in MOFA env
$MOFA_RUN conda install -y redis

# Install and start MongoDB (no systemd)
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-8.0.list
apt-get update && apt-get install -y mongodb-org

mkdir -p /var/lib/mongodb /var/log
mongod --dbpath /var/lib/mongodb --fork --logpath /var/log/mongod.log
ps -fe | grep mongo >> /var/log/mofa-install.log

# Download and extract libtorch
cd /root
wget https://download.pytorch.org/libtorch/cpu/libtorch-shared-with-deps-2.5.1%2Bcpu.zip -O libtorch.zip
unzip libtorch.zip
rm libtorch.zip

# Compile LAMMPS with MACE support
git clone --branch mace --depth=1 https://github.com/ACEsuit/lammps
cd lammps; mkdir build-mace; cd build-mace
cmake -DCMAKE_INSTALL_PREFIX=$(pwd) \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_STANDARD_REQUIRED=ON \
      -DBUILD_MPI=ON \
      -DBUILD_OMP=ON \
      -DPKG_OPENMP=ON \
      -DPKG_ML-MACE=ON \
      -DCMAKE_PREFIX_PATH=/root/libtorch \
      -DMKL_INCLUDE_DIR=/usr/include/mkl \
      ../cmake
make -j$(nproc)
make install

# Check LAMMPS MACE support
LD_LIBRARY_PATH=/root/libtorch/lib:$LD_LIBRARY_PATH ./bin/lmp -h | grep mace >> /var/log/mofa-install.log

# Assemble input files
cd /root/mof-generation-at-scale/input-files/zn-paddle-pillar
$MOFA_RUN python assemble_inputs.py
ls -l /root/mof-generation-at-scale/input-files/zn-paddle-pillar >> /var/log/mofa-install.log

# Fetch MACE model
cd /root/mof-generation-at-scale/input-files/mace
$MOFA_RUN ./get-macemp-0a.sh
ls -l /root/mof-generation-at-scale/input-files/mace >> /var/log/mofa-install.log

# Launch Redis server -- now through docker-compose
# $MOFA_RUN redis-server --daemonize yes >> /var/log/mofa-install.log 2>&1

# change  ~/mof-generation-at-scale/mofa/hpc/config.py
tmp_file=$(mktemp)
cat <<'EOF' > "$tmp_file"
    torch_device = 'cpu'
    lammps_env = {}
    lammps_cmd = ( 'LD_LIBRARY_PATH=~/libtorch/lib:$LD_LIBRARY_PATH ~/lammps/build-mace/bin/lmp', )
EOF

sed -i '94,96d' ~/mof-generation-at-scale/mofa/hpc/config.py
sed -i "93r $tmp_file" ~/mof-generation-at-scale/mofa/hpc/config.py

rm "$tmp_file"

$MOFA_RUN pip install "diaspora-event-sdk[kafka-python]"
$MOFA_RUN pip install --upgrade "proxystore[all]" confluent-kafka aws-msk-iam-sasl-signer-python
