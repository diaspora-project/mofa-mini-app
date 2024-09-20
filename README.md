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

