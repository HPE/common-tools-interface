#!/bin/bash

set -e

install_dir="${install_dir=${HOME}/hpe-tools}"

reconfigure=
prep=
for arg in "$@"; do
    if [ $arg == "--prep" ]; then
	prep=1
    elif [ $arg == "--reconfigure" ]; then
	reconfigure='--reconfigure'
    else
	echo "usage $0 [--prep]"
	exit 1
    fi
done

if [ -n "$prep" ]; then
    if [ "$(whoami)" != "root" ]; then
	echo "--prep must be run as root"
	exit 1
    fi
    echo prepping
    yum install libssh2-devel boost-devel dyninst-devel pandoc
    exit
fi

if [ $(gcc --version | grep -c '\<14\.') != 1 ]; then
    source /opt/rh/gcc-toolset-14/enable
fi    

top_level="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "############################################"
echo "#      Building CTI                        #"
echo "############################################"
# Create autotools generated files for this build environment

# we explicitly set CC/CXX here to their full paths so that the full paths are
# baked into the meson build configuration and meson doesn't use whatever gcc/g++ is
# in PATH on subsequent builds outside of runBuild.sh
CC=$(which gcc) CXX=$(which g++) \
  meson setup \
    -Dprefix=$install_dir \
    -Dlibdir=lib/cti \
    -Dflux-dir=hpe/external/libalps_headers \
    -Dpals-dir=hpe/external/libalps_headers \
    -Ddebug=true \
    -Doptimization=2 \
    -Db_ndebug=true \
    $reconfigure \
    ./build



if [ -z "$reconfigure" ]; then

    meson compile --verbose -C build

    meson install -C build
fi    

echo "############################################"
echo "#              Done with build             #"
echo "############################################"

