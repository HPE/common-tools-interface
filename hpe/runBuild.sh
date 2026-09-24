#!/bin/bash
#
# runBuild.sh - Build steps for CTI
#
# Copyright 2019-2026 Hewlett Packard Enterprise Development LP
#
# Unpublished Proprietary Information.
# This unpublished work is protected to trade secret, copyright and other laws.
# Except as permitted by contract or express written permission of Hewlett
# Packard Enterprise Development LP., no part of this work or its content may be
# used, reproduced or disclosed in any form.
#

echo "############################################"
echo "#            Setup environment.            #"
echo "############################################"

# directory of this script
hpe="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$hpe/external/cdst_build_library/build_lib_gcc"

source "$hpe/../release_versioning"

cti_version=
branch_name=$(get_branch_info)
branch_type=$(echo "$branch_name" | cut -d'/' -f1)
if [ "$branch_type" != "release" ]; then
  cti_version="$common_tool_major.$common_tool_minor.$revision.$build_number"
else
  cti_version="$common_tool_major.$common_tool_minor.$revision"
fi
install_dir="/opt/cray/pe/cti/$cti_version"

if [[ ! -z $BRANCH_NAME ]]; then
  echo "cleaning build env"
  rm -rf /opt/cray/pe/cti
fi

setup_modules

module load cray-dyninst
check_exit_status

module list

echo "############################################"
echo "#      Copying subprojects                  "
echo "############################################"

"$hpe/wrap.sh" libarchive googletest
check_exit_status

echo "############################################"
echo "#      Building CTI                        #"
echo "############################################"

cd $hpe/..

# we explicitly set CC/CXX here to their full paths so that the full paths are
# baked into the meson build configuration and meson doesn't use whatever gcc/g++ is
# in PATH on subsequent builds outside of runBuild.sh
CC=$(which gcc) CXX=$(which g++) \
  meson setup \
  -Dprefix=$install_dir \
    -Dlibdir=lib \
    -Dflux-dir=hpe/external/libalps_headers \
    -Dpals-dir=hpe/external/libalps_headers \
    -Ddebug=true \
    -Doptimization=2 \
    -Db_ndebug=true \
    ./build --force-fallback-for=libarchive
check_exit_status


meson compile --verbose -C build
check_exit_status

meson install -C build
check_exit_status

export PKG_CONFIG_PATH=$install_dir/lib/pkgconfig:$PKG_CONFIG_PATH
export CTI_INSTALL_DIR=$install_dir
make -C ./tests/test_support all
make -C ./tests/function/src tests
make -C ./tests/pipeline/opt/cray/tests/cdst/resources/cti/smoke prebuilt


echo "############################################"
echo "#              Done with build             #"
echo "############################################"

exit_with_status
