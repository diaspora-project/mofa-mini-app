#!/bin/bash

export LD_LIBRARY_PATH="$(find /home/runner/work/  -type d -name "lib" -print | tr '\n' ':'q):${LD_LIBRARY_PATH}"

t_assembly="mofa_test2_assembly_result"
t_cp2k="mofa_test2_cp2k_result"
t_default="mofa_test2_default_result"
t_generation="mofa_test2_generation_result"
t_lammps="mofa_test2_lammps_result"
t_requests="mofa_test2_requests"
t_training="mofa_test2_training_result"
groupfile="/mnt/mofa/mofka.json"

bedrock tcp -c mofka_config.json &
sleep 5
cat mofka.json
cp mofka.json ${groupfile}
BEDROCK_PID=$!
mofkactl topic create ${t_assembly} --groupfile ${groupfile}
mofkactl partition add ${t_assembly} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_cp2k} --groupfile ${groupfile}
mofkactl partition add ${t_cp2k} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_default} --groupfile ${groupfile}
mofkactl partition add ${t_default} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_generation} --groupfile ${groupfile}
mofkactl partition add ${t_generation} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_lammps} --groupfile ${groupfile}
mofkactl partition add ${t_lammps} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_requests} --groupfile ${groupfile}
mofkactl partition add ${t_requests} --type memory --rank 0 --groupfile ${groupfile}

mofkactl topic create ${t_training} --groupfile ${groupfile}
mofkactl partition add ${t_training} --type memory --rank 0 --groupfile ${groupfile}

wait ${BEDROCK_PID}