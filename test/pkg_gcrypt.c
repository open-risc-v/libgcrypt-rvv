// libgcrypt A/B 探针：SHA-256 摘要 + AES-128-CBC 回环，覆盖 hash 与 cipher 两条主路径。
// 只用公开 API；密文、摘要任一字节不同都会被抓到。
#include <gcrypt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define N 65536

static uint64_t fnv1a(const void *p, size_t n)
{
    const uint8_t *b = p;
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}

static int cbc(const unsigned char *in, size_t n, unsigned char *out, int enc)
{
    unsigned char key[16], iv[16];
    for (int i = 0; i < 16; i++) { key[i] = (unsigned char)(0x11 + i); iv[i] = (unsigned char)(0x90 + i); }
    gcry_cipher_hd_t hd;
    if (gcry_cipher_open(&hd, GCRY_CIPHER_AES128, GCRY_CIPHER_MODE_CBC, 0)) return -1;
    int rc = gcry_cipher_setkey(hd, key, 16) || gcry_cipher_setiv(hd, iv, 16);
    if (rc) { gcry_cipher_close(hd); return -1; }
    gcry_cipher_final(hd);                     /* 定长输入，显式收尾，不留 padding */
    rc = enc ? gcry_cipher_encrypt(hd, out, n, in, n)
             : gcry_cipher_decrypt(hd, out, n, in, n);
    gcry_cipher_close(hd);
    return rc ? -1 : 0;
}

int main(int argc, char **argv)
{
    const char *outb = argc > 1 ? argv[1] : NULL;
    if (!gcry_check_version(GCRYPT_VERSION)) { fprintf(stderr, "版本不匹配\n"); return 2; }
    gcry_control(GCRYCTL_DISABLE_SECMEM, 0);
    gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0);

    unsigned char *plain = malloc(N), *enc = malloc(N), *dec = malloc(N);
    unsigned char md[32];
    if (!plain || !enc || !dec) return 3;
    for (size_t i = 0; i < N; i++) plain[i] = (unsigned char)((i * 41 + (i >> 10)) & 0xff);

    if (cbc(plain, N, enc, 1) != 0) { fprintf(stderr, "encrypt失败\n"); return 4; }
    if (cbc(enc, N, dec, 0) != 0) { fprintf(stderr, "decrypt失败\n"); return 5; }
    if (memcmp(plain, dec, N) != 0) { fprintf(stderr, "回环不一致\n"); return 6; }

    gcry_md_hash_buffer(GCRY_MD_SHA256, md, plain, N);

    printf("n=%d ver=%s sha256=", N, gcry_check_version(NULL));
    for (int i = 0; i < 32; i++) printf("%02x", md[i]);
    printf(" fnv_ct=%016llx\n", (unsigned long long)fnv1a(enc, N));

    if (outb) {
        FILE *f = fopen(outb, "wb");
        if (!f) return 7;
        fwrite(enc, 1, N, f);
        fclose(f);
    }
    free(plain); free(enc); free(dec);
    return 0;
}
