#!/usr/bin/env bash
# 交叉编译基线版本：libgcrypt 依赖 libgpg-error，riscv64 侧没有预编译包，
# 先在容器里用发行版源码把 libgpg-error 交叉编到 build/riscv64-b/gperr，
# 再把 baseline 编到 build/riscv64-b/prefix，探针用 qemu-user 跑。
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${IMAGE:-rvv-cross-gperr:3}
MARCH=${MARCH:-rv64gc}
OUT=build/riscv64-b

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}
# 1) libgpg-error 1.61：镜像 rvv-cross-gperr:3 已交叉编到 /opt/gpg-error
#    （源码 gnupg.org 官方 tar，1.61 起只装 gpgrt-config，镜像里补了 gpg-error-config
#     shim 供 libgcrypt 的 m4 使用；构建细节见 docs/10-cross-baseline.md）
[ -f /opt/gpg-error/lib/libgpg-error.a ] || { echo '缺 /opt/gpg-error（用 rvv-cross-gperr:3 镜像）'; exit 1; }

# 2) libgcrypt baseline（复制后 autoreconf，不改 baseline 树）
mkdir -p ${OUT} && cp -R /work/baseline ${OUT}/src && rm -rf ${OUT}/src/.git
cd ${OUT}/src && autoreconf -fi > /dev/null 2>&1
cd /work && mkdir -p ${OUT}/bld && cd ${OUT}/bld
/work/${OUT}/src/configure --host=riscv64-linux-gnu --prefix=/work/${OUT}/prefix \
  --disable-shared --enable-static --disable-doc \
  --with-libgpg-error-prefix=/opt/gpg-error \
  CFLAGS='-march=${MARCH} -O2' CPPFLAGS='-I/opt/gpg-error/include' > /tmp/gc-cfg.log 2>&1 || { tail -25 /tmp/gc-cfg.log; exit 1; }
make -j\$(nproc) > /tmp/gc-bld.log 2>&1 || { tail -20 /tmp/gc-bld.log; exit 1; }
make install > /dev/null

# 3) 探针
cmake -S /work -B /work/${OUT}/harness -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' -DPKG_PREFIX=/work/${OUT}/prefix \
  -DGPGERR_ROOT=/opt/gpg-error > /tmp/h.log 2>&1 || { tail -25 /tmp/h.log; exit 1; }
cmake --build /work/${OUT}/harness -j > /tmp/hb.log 2>&1 || { tail -20 /tmp/hb.log; exit 1; }

cd /work && mkdir -p ${OUT}/out
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/gcrypt_harness ${OUT}/out/cipher.bin > ${OUT}/out/hash.txt
echo \"--- riscv64（${MARCH}）---\"; cat ${OUT}/out/hash.txt
echo \"--- native 基线 ---\"; cat build/ab-data/out/01_gcrypt_aes/a/hash.txt
"
