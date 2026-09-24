#!/bin/bash
#
# runBuildPrep.sh - Preps the build environment
#
# Copyright 2019-2024 Hewlett Packard Enterprise Development LP
# SPDX-License-Identifier: Linux-OpenIB

# directory of this script
hpe="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source "$hpe/external/cdst_build_library/build_lib"

echo "############################################"
echo "#             Installing deps              #"
echo "############################################"
target_pm=$(get_pm)
target_os=$(get_os)
target_arch=$(get_arch)
if [[ "$target_pm" == "$cdst_pm_zypper" ]]; then
    if [[ "$target_arch" == "$cdst_arch_x86_64" ]]; then
      sudo zypper refresh -f
    elif [[ "$target_arch" == "$cdst_arch_aarch64" && "$target_os" -ge "$cdst_os_sles15sp5" ]]; then
      sudo zypper --non-interactive install libopenssl-devel
    fi
    # Install zypper based dependencies
    zypper --non-interactive install \
        binutils \
        binutils-devel \
        cmake \
        glibc-devel-static \
        m4 \
        make \
        make-lang \
        mksh \
        meson \
        libboost_headers1_66_0-devel \
        libtool \
        libssh2-devel \
        rpm-build \
        python3-pip \
        python311 \
        zlib-devel \
        libarchive-devel
    check_exit_status

elif [[ "$target_pm" == "$cdst_pm_yum" ]]; then
    if [[ "$target_os" == "$cdst_os_centos8" ]]; then 
      # Note the following will be different on build VMs vs DST. Errors are okay.
      yum config-manager --set-enabled powertools
    fi
    # Install yum based components
    yum --assumeyes install \
        binutils \
        binutils-devel \
        boost-devel \
        cmake \
        dyninst-devel \
        environment-modules \
        glibc-devel \
        m4 \
        make \
        meson \
        libssh2-devel \
        libtool \
        pandoc \
        rpm-build \
        zlib-devel \
        tcl \
        python3-pip \
        python3.11 \
        wget \
        autoconf-archive \
        libarchive-devel
    check_exit_status

else
    # Unknown OS! Exit with error.
    echo "Unsupported Package Manager detected!"
    exit 1
fi

# Install the common PE components
install_common_pe
check_exit_status

# Install cdst-support & Dyninst
install_dyninst
check_exit_status

python3 -m ensurepip --upgrade
check_exit_status

capture_jenkins_build
check_exit_status

echo "############################################"
echo "#          Done with build prep            #"
echo "############################################"

exit_with_status
