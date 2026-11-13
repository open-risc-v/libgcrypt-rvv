# 交叉编译基线（riscv64）— libgcrypt

日期：2026-11-13

## 口径

- 只编上游 **baseline**（不改源码、不加 RVV 内核）；
- `MARCH=rv64gc`（无向量扩展），`riscv64-linux-gnu-gcc 13.3`（`rvv-cross-gperr:3` 镜像）；
- 运行：`qemu-riscv64 -L /usr/riscv64-linux-gnu`（静态链接）；
- 探针 `test/pkg_gcrypt.c`：64 KiB 固定语料，SHA-256 + AES-128-CBC（关 padding），
  输出 `hash.txt`；与 native（`build/ab-data/out/01_gcrypt_aes/a/hash.txt`）逐字段比。

## 前置：libgpg-error 1.61（riscv64）

libgcrypt 要求 `libgpg-error >= 1.56`（`configure.ac:77`），发行版只有 1.47。做法：

```bash
curl -LO https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.bz2
# 在 rvv-cross:1 上交叉编到 /opt/gpg-error（--disable-shared --enable-static），
# 1.61 起只装 gpgrt-config，libgcrypt 的 m4 仍调 gpg-error-config，故补一个 shim
docker build -t rvv-cross-gperr:3 .
```

两个坑：

1. `gpg-error-config` 在 1.61 已不存在 → configure 报 `checking for GPG Error - version >= 1.56... no`；
   shim 输出 `--version/--cflags/--libs/--host` 即可。
2. libgcrypt 的 `tests/` 直接用 `-I../src` 而不带 `GPG_ERROR_CFLAGS` → 必须给全局
   `CPPFLAGS=-I/opt/gpg-error/include`，否则 `tests/t-lock.c` 编不过。

## 结果

| 侧 | 输出 |
|---|---|
| riscv64（rv64gc） | `n=65536 ver=1.12.5-unknown sha256=8ae5324f…3f50ea7 fnv_ct=1b61c683d7e61c03` |
| native（arm64 macOS） | `n=65536 ver=1.12.5-unknown sha256=8ae5324f…3f50ea7 fnv_ct=1b61c683d7e61c03` |

**全字段一致**。libgcrypt 的 RVV 内核尚未编写，因此这条基线证明的是“上游能在 riscv64 编、
真实加解密路径能跑、探针口径可比”，不是加速。

## 复现

```bash
cd ~/work/libgcrypt-rvv
IMAGE=rvv-cross-gperr:3 ./scripts/cross-baseline.sh   # 默认已是 :3
```
