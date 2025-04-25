# Dockerfile based on Ubuntu 22.04 (the OS version is important to Mofka and MOFA)

FROM ghcr.io/mochi-hpc/mochi-spack-buildcache:mofka-0.6.4-6jvujfbrsndd4aqsxc5ag4uicyjnkkxp.spack

COPY prereq.sh /root/prereq.sh
RUN chmod +x /root/prereq.sh
RUN bash /root/prereq.sh

ENV PATH="/opt/conda/bin:$PATH"

COPY example-parallel-run.sh /root/mof-generation-at-scale/example-parallel-run.sh
RUN chmod +x /root/mof-generation-at-scale/example-parallel-run.sh

COPY ensure_endpoint.sh /root/mof-generation-at-scale/ensure_endpoint.sh
RUN chmod +x /root/mof-generation-at-scale/ensure_endpoint.sh

# used for local development
# COPY run_parallel_workflow.py /root/mof-generation-at-scale/run_parallel_workflow.py

WORKDIR /root/mof-generation-at-scale
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "mofa", "./example-parallel-run.sh"]