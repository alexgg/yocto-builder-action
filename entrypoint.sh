#!/usr/bin/env bash
set -x

machine="${1}"
[ -z "${machine}" ] && echo "[ERROR] Machine is required" && exit 1
target="${2}"
[ -z "${target}" ] && echo "[ERROR] Bitbake target is required" && exit 1
templateconf="${3}"
extraconf="${4}"

workdir="${GITHUB_WORKSPACE}/src"
uid=$(ls -d -n ${workdir} | awk '{ print $3 }')
gid=$(ls -d -n ${workdir} | awk '{ print $4 }')
# Bitbake cannot be used as root
sudo chown build:build "${workdir}"
pushd "${workdir}" || exit 1

if [ -n "${templateconf}" ]; then
	export TEMPLATECONF="${templateconf}"
fi
# shellcheck disable=SC1091
source layers/poky/oe-init-build-env build
if [ -n "${extraconf}" ]; then
	EXTRA_ARGS="--postread=${extraconf}"
fi
# shellcheck disable=SC2086
MACHINE="${machine}" bitbake "${target}" ${EXTRA_ARGS}
targz=$(find "${workdir}/build/tmp/deploy/images/${machine}/" -type l -name "${target}*.tar.gz")
if [ ! -L "${targz}" ]; then
	echo "Build failed" && exit 1
fi
targz=${targz#${GITHUB_WORKSPACE}/*}
echo "::set-output name=targz::$targz"
ARCH=$("${machine}" bitbake "${target}" -e | grep ^TUNE_ARCH= | cut -d "=" -f2 | tr -d '"')
if [ -n "${ARCH}" ]; then
	echo "::set-output name=arch::$ARCH"
fi
KERNEL_VERSION=$("${machine}" bitbake virtual/kernel -e | grep ^PV= | cut -d "=" -f2 | cut -d "+" -f1 | tr -d '"')
if [ -n "${KERNEL_VERSION}" ]; then
	echo "::set-output name=kernel-version::$KERNEL_VERSION"
fi
# Restore permissions so the contents can be removed by other actions
sudo chown ${uid}:${gid} "${workdir}" -R || true
