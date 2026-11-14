/* libgcrypt 吞吐基准：SHA-256（16 MiB）与 AES-256-CTR（16 MiB）。
   A（asm/RVV 路径）/ B（--disable-asm）同 -march，真机上交替跑取最优。 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <gcrypt.h>

static double now_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(int argc, char **argv)
{
	int reps = argc > 1 ? atoi(argv[1]) : 5;
	size_t n = 16u << 20;
	unsigned char *buf = malloc(n);
	if (!buf) return 2;
	for (size_t i = 0; i < n; i++) buf[i] = (unsigned char)(i * 131 + 7);
	gcry_check_version(NULL);

	double best_h = 1e30, best_c = 1e30;
	unsigned char key[32], ctr[16];
	for (int i = 0; i < 32; i++) key[i] = (unsigned char)i;
	memset(ctr, 0, sizeof ctr);

	for (int r = 0; r < reps; r++) {
		unsigned char h[32];
		double t0 = now_ns();
		gcry_md_hash_buffer(GCRY_MD_SHA256, h, buf, n);
		double dt = now_ns() - t0;
		if (dt < best_h) best_h = dt;
		if (r == 0) printf("sha256=%02x%02x%02x%02x\n", h[0], h[1], h[2], h[3]);

		gcry_cipher_hd_t ch;
		gcry_cipher_open(&ch, GCRY_CIPHER_AES256, GCRY_CIPHER_MODE_CTR, 0);
		gcry_cipher_setkey(ch, key, 32);
		gcry_cipher_setctr(ch, ctr, 16);
		t0 = now_ns();
		gcry_cipher_encrypt(ch, buf, n, NULL, 0);
		double dt2 = now_ns() - t0;
		if (dt2 < best_c) best_c = dt2;
		gcry_cipher_close(ch);
	}
	printf("sha256_16M_ns=%.0f aesctr_16M_ns=%.0f sha256_MBps=%.1f aesctr_MBps=%.1f\n",
	       best_h, best_c, 16.0 / (best_h / 1e9) , 16.0 / (best_c / 1e9));
	free(buf);
	return 0;
}
