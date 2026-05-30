#!/bin/bash
# LAMMPS launcher for the ACEsuit `mace` build (pair_style mace), used as
# CloudVMConfig's $MOFA_LAMMPS_BIN.
#
# lmp is dynamically linked against libtorch (libtorch_cpu.so / libc10.so), so
# it needs /opt/libtorch/lib on LD_LIBRARY_PATH. MACERunner runs lmp with
# env=None, i.e. it inherits the workflow process environment — which in mofka
# mode carries the bedrock client's LD_PRELOAD (conda lmdb/leveldb) and a conda
# LD_LIBRARY_PATH. Those make lmp (built against the Ubuntu system toolchain)
# fail to find libtorch and risk a conda/system libstdc++ clash. We therefore
# reset to a clean, libtorch-only environment scoped to lmp alone.
exec env -u LD_PRELOAD LD_LIBRARY_PATH=/opt/libtorch/lib \
  /opt/lammps/build-mace/bin/lmp "$@"
