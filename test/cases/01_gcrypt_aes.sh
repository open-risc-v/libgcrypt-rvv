#!/usr/bin/env bash
# 真实包用例：libgcrypt 的 SHA-256 + AES-128-CBC 回环，比较摘要与密文字节。
set -euo pipefail
: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"
case "$STAGE" in
  gen) ;;
  run)
    [ -x "$BIN/gcrypt_harness" ] || { echo "缺少 $BIN/gcrypt_harness" >&2; exit 1; }
    "$BIN/gcrypt_harness" "$OUT/cipher.bin" > "$OUT/hash.txt"
    size=$(wc -c < "$OUT/cipher.bin" | tr -d ' ')
    [ "$size" -eq 65536 ] || { echo "密文长度异常：$size" >&2; exit 1; }
    ;;
  *) echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
