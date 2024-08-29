# MOFA Mini App

A containerized example application of MOF generation code found [here](https://github.com/globus-labs/mof-generation-at-scale/tree/main).

### How to run:

0. Create your GitHub personal access token, see [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic).

#### Docker
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

#### Apptainer on Polaris [Not currently working]
1. Load Apptainer modules
```
module use /soft/spack/gcc/0.6.1/install/modulefiles/Core
module load apptainer
```
  
2. Pull image from Github Registry
```
echo <personal_access_token> | apptainer remote login -u valhayot --password-stdin docker://ghcr.io
apptainer pull docker://ghcr.io/diaspora-project/mofa-mini-app:main
```

3. Run container to execute application
```
apptainer run mofa-mini-app_main.sif
```
