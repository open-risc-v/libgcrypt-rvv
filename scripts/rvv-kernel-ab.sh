#!/usr/bin/env bash
# libgcrypt G3：RVV / Zvk* 汇编路径（chacha20 / sha1 / sha256 / sha512 / sm3 / sm4 / poly1305）
# A = 默认（检测到 riscv 向量汇编即启用） @ rv64gcv，B = --disable-asm @ 同一 march。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross-gperr:3}
MARCH=${MARCH:-rv64gcv}
OUT=build/rvv-k

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
[ -f /opt/gpg-error/lib/libgpg-error.a ] || { echo '缺 /opt/gpg-error'; exit 1; }
rm -rf ${OUT}; mkdir -p ${OUT}
for side in on off; do
  opt=''
  if [ \"\$side\" = off ]; then opt='--disable-asm'; fi
  mkdir -p ${OUT}/\$side && cp -R /work/baseline ${OUT}/\$side/src && rm -rf ${OUT}/\$side/src/.git
  ( cd ${OUT}/\$side/src && autoreconf -fi > /dev/null 2>&1 )
  mkdir -p ${OUT}/\$side/bld && cd ${OUT}/\$side/bld
  /work/${OUT}/\$side/src/configure --host=riscv64-linux-gnu --prefix=/work/${OUT}/\$side/prefix \
    --disable-shared --enable-static --disable-doc --with-libgpg-error-prefix=/opt/gpg-error \$opt \
    CFLAGS='-march=${MARCH} -O2' CPPFLAGS='-I/opt/gpg-error/include' > /work/${OUT}/\$side-cfg.log 2>&1 \
    || { tail -25 /work/${OUT}/\$side-cfg.log; exit 1; }
  make -j\$(nproc) > /work/${OUT}/\$side-build.log 2>&1 || { tail -25 /work/${OUT}/\$side-build.log; exit 1; }
  make install > /dev/null
  cd /work

  cmake -S /work -B /work/${OUT}/\$side/harness -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS='-march=${MARCH}' -DPKG_PREFIX=/work/${OUT}/\$side/prefix \
    -DGPGERR_ROOT=/opt/gpg-error > /dev/null 2>&1
  cmake --build /work/${OUT}/\$side/harness -j > /work/${OUT}/\$side-harness.log 2>&1 \
    || { tail -15 /work/${OUT}/\$side-harness.log; exit 1; }
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/\$side/harness/gcrypt_harness ${OUT}/\$side/cipher.bin > ${OUT}/\$side/hash.txt

  riscv64-linux-gnu-gcc -O3 -march=${MARCH} -static -I ${OUT}/\$side/prefix/include -I /opt/gpg-error/include \
    test/bench_gcrypt.c ${OUT}/\$side/prefix/lib/libgcrypt.a /opt/gpg-error/lib/libgpg-error.a -o ${OUT}/\$side/bench 2>/dev/null || true
done

echo '--- A：asm/RVV 启用 ---'; cat ${OUT}/on/hash.txt
echo '--- B：--disable-asm ---'; cat ${OUT}/off/hash.txt
cmp -s ${OUT}/on/hash.txt ${OUT}/off/hash.txt && echo '== 功能一致' || echo '== 功能不一致'
"
