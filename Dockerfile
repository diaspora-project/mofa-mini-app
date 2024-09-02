FROM continuumio/miniconda3:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN git clone https://github.com/globus-labs/mof-generation-at-scale.git

RUN conda update -n base conda \
    && conda install -n base conda-libmamba-solver \
    && conda config --set solver libmamba \
    && cd mof-generation-at-scale/envs \
    && conda env create --file environment-cuda11.yml

SHELL ["conda", "run", "--no-capture-output", "-n", "mofa", "/bin/bash", "-c"]
RUN conda install -y redis mongodb

WORKDIR /mof-generation-at-scale

RUN cd input-files/zn-paddle-pillar && python assemble_inputs.py

COPY run_mini_app.sh .
COPY config.py mofa/hpc/

ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "mofa", "/bin/bash", "run_mini_app.sh"]
