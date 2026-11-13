#!/usr/bin/env bash
# 本机不编译：native 基线在 Linux 容器里跑。
# libgcrypt 需要 libgpg-error >= 1.56：镜像里自带一份装在 /opt/gpg-error-native。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:-${IMAGE:-rvv-build:2}}
docker run --rm -v "$PWD":/work -w /work \
  -e GPGERR_ROOT=/opt/gpg-error-native \
  -e PKG_CONFIG_PATH=/opt/gpg-error-native/lib/pkgconfig \
  -e PATH=/opt/gpg-error-native/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  "${IMAGE}" bash -lc '
  set -e
  rm -rf build/ab-a build/ab-b build/ab-data
  ./test/run_ab.sh
'
