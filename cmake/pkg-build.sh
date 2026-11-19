#!/usr/bin/env bash
# libgcrypt：上游只有 configure.ac，需要 autoreconf。为了不弄脏 baseline 树，
# 先把它复制到 <OUT>/src 再生成 configure，然后 out-of-tree 构建静态库。
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gcv}
KERN=${4:-0}
rm -rf "${OUT}"
mkdir -p "${OUT}/bld"
cp -R "${SRC}" "${OUT}/src"
rm -rf "${OUT}/src/.git"
cd "${OUT}/src"
autoreconf -fi >/dev/null 2>&1
cd "${OUT}/bld"
if [ "$KERN" = "1" ]; then export CFLAGS="${CFLAGS:-} -march=${MARCH} -DRVV_KERNELS=1"; else export CFLAGS="${CFLAGS:-}"; fi
"${OUT}/src/configure" --prefix="${OUT}/prefix" --disable-shared --enable-static \
  --disable-doc --disable-tests >/dev/null
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)" >/dev/null
make install >/dev/null
echo "== 上游 libgcrypt 构建完成：${OUT}/prefix"
