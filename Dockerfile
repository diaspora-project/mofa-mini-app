FROM continuumio/miniconda3:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN git clone https://github.com/globus-labs/mof-generation-at-scale.git

WORKDIR /mof-generation-at-scale

RUN git checkout proxystream

RUN conda update -n base conda \
    && conda install -n base conda-libmamba-solver \
    && conda config --set solver libmamba \
    && conda env create --file envs/environment-cpu.yml

SHELL ["conda", "run", "--no-capture-output", "-n", "mofa", "/bin/bash", "-c"]
RUN conda install -y redis mongodb

RUN pip install --upgrade aws-msk-iam-sasl-signer-python
RUN pip install --upgrade confluent_kafka
# by default, colmena 0.6 installs proxystore 0.6.5, 
# we want proxystore 0.7.1 (latest) for confluent_kafka streaming support
RUN pip install --upgrade "proxystore[all]" 

RUN cd input-files/zn-paddle-pillar && python assemble_inputs.py

COPY run_mini_app.sh .
COPY ensure_endpoint.sh .
COPY config.py mofa/hpc/

ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "mofa", "/bin/bash", "run_mini_app.sh"]
