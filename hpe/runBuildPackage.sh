#!/bin/bash
#
# runBuildPackage.sh - Package steps for CTI
#
# Copyright 2019-2023 Hewlett Packard Enterprise Development LP
# SPDX-License-Identifier: Linux-OpenIB
#
# Unpublished Proprietary Information.
# This unpublished work is protected to trade secret, copyright and other laws.
# Except as permitted by contract or express written permission of Hewlett
# Packard Enterprise Development LP., no part of this work or its content may be
# used, reproduced or disclosed in any form.
#

# directory of this script
hpe="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$hpe/external/cdst_build_library/build_lib"

top_dir="$hpe/.."

setup_modules

module load cray-dyninst
check_exit_status

echo "############################################"
echo "#          Generating Cpedocs              #"
echo "############################################"

# This doesn't deliver any documentation anywhere, it only tests the
# low bar that collect_cpedocs.sh still runs without an error.
pushd "$hpe/cpedocs"
./collect_cpedocs.sh
check_exit_status
popd

echo "############################################"
echo "#             Creating rpm                 #"
echo "############################################"
rpmbuilddir="$hpe/rpmbuild"

cp "$top_dir/release_notes.md" $rpmbuilddir/SOURCES/release_notes.md

cd ${rpmbuilddir}
check_exit_status
rpmbuild -bb -D "_topdir ${rpmbuilddir}" SPECS/cray-cti.spec
check_exit_status

if [ -f "$hpe/rpmbuild/BUILD/release_notes.md" ]; then
  echo
  echo
  echo "Release Notes in rpmbuild/BUILD:"
  cat "$hpe/rpmbuild/BUILD/release_notes.md"
fi

echo "############################################"
echo "#          Done with packaging             #"
echo "############################################"

exit_with_status
