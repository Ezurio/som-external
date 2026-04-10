// SPDX-License-Identifier: LicenseRef-Ezurio-Clause
/*
 * dmcrypt_image - create an offline dm-crypt plain-mode encrypted image.
 *
 * Produces output byte-identical to the Linux kernel dm-crypt target.
 * Depends only on libcrypto (OpenSSL).
 *
 * Build:
 *   gcc -O2 -o dmcrypt_image dmcrypt_image.c -lcrypto
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/stat.h>
#include <openssl/evp.h>
#include <openssl/sha.h>

#define SECTOR_SIZE    512
#define BATCH_SECTORS  1024
#define MAX_KEY_BYTES  64

enum cipher_mode { MODE_XTS, MODE_CBC_ESSIV };

/* ── helpers ──────────────────────────────────────────────────────────────── */

static off_t parse_size(const char *s)
{
	char *end;
	off_t v = (off_t)strtoll(s, &end, 10);
	if (end == s) {
		fprintf(stderr, "error: invalid size: %s\n", s);
		return -1;
	}
	switch (*end | 0x20) {
	case 'k': v <<= 10; break;
	case 'm': v <<= 20; break;
	case 'g': v <<= 30; break;
	case 't': v <<= 40; break;
	case '\0': break;
	default:
		fprintf(stderr, "error: unknown size suffix: %c\n", *end);
		return -1;
	}
	return v;
}

static void sector_to_le128(uint64_t sector, uint8_t out[16])
{
	int i;

	memset(out, 0, 16);
	for (i = 0; i < 8; i++)
		out[i] = (sector >> (i * 8)) & 0xff;
}

/* ── key derivation (cryptsetup lib/utils.c : crypt_plain_hash) ───────────── */

static int plain_hash_key(const uint8_t *pass, size_t passlen,
			  const char *hash_name,
			  uint8_t *key, size_t keylen)
{
	const EVP_MD *md;
	size_t dlen;
	size_t done = 0;
	int block;

	md = EVP_get_digestbyname(hash_name);
	if (!md)
		return -1;

	dlen = (size_t)EVP_MD_size(md);

	for (block = 0; done < keylen; block++) {
		EVP_MD_CTX *ctx;
		uint8_t buf[EVP_MAX_MD_SIZE];
		unsigned int blen = 0;
		size_t copy;
		int i;

		ctx = EVP_MD_CTX_new();
		EVP_DigestInit_ex(ctx, md, NULL);
		/* prepend 'block' NUL bytes */
		for (i = 0; i < block; i++) {
			uint8_t zero = 0;
			EVP_DigestUpdate(ctx, &zero, 1);
		}
		EVP_DigestUpdate(ctx, pass, passlen);
		EVP_DigestFinal_ex(ctx, buf, &blen);
		EVP_MD_CTX_free(ctx);

		copy = (done + dlen > keylen) ? (keylen - done) : dlen;
		memcpy(key + done, buf, copy);
		memset(buf, 0, sizeof(buf));
		done += copy;
	}
	return 0;
}

/* ── AES-XTS-plain64 ──────────────────────────────────────────────────────── */

static void encrypt_xts(const uint8_t *key, size_t keylen,
			const uint8_t *in, uint8_t *out,
			size_t n_sectors, uint64_t start_sector)
{
	/* EVP_aes_128_xts: 32-byte key (two 128-bit halves)
	 * EVP_aes_256_xts: 64-byte key (two 256-bit halves) */
	const EVP_CIPHER *cipher = (keylen == 32) ? EVP_aes_128_xts()
						   : EVP_aes_256_xts();
	EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
	size_t i;

	for (i = 0; i < n_sectors; i++) {
		uint8_t iv[16];
		int outl = 0, outl2 = 0;

		sector_to_le128(start_sector + i, iv);

		EVP_EncryptInit_ex(ctx, cipher, NULL, key, iv);
		EVP_CIPHER_CTX_set_padding(ctx, 0);

		EVP_EncryptUpdate(ctx, out + i * SECTOR_SIZE, &outl,
				  in  + i * SECTOR_SIZE, SECTOR_SIZE);
		EVP_EncryptFinal_ex(ctx, out + i * SECTOR_SIZE + outl, &outl2);
	}
	EVP_CIPHER_CTX_free(ctx);
}

/* ── AES-CBC-ESSIV:sha256 ─────────────────────────────────────────────────── */

static void encrypt_cbc_essiv(const uint8_t *key, size_t keylen,
			      const uint8_t *in, uint8_t *out,
			      size_t n_sectors, uint64_t start_sector)
{
	uint8_t essiv_key[32];
	const EVP_CIPHER *ecb;
	const EVP_CIPHER *cbc;
	EVP_CIPHER_CTX *ecb_ctx;
	EVP_CIPHER_CTX *cbc_ctx;
	size_t i;

	SHA256(key, keylen, essiv_key);

	ecb = EVP_aes_256_ecb();
	switch (keylen) {
	case 16: cbc = EVP_aes_128_cbc(); break;
	case 24: cbc = EVP_aes_192_cbc(); break;
	default: cbc = EVP_aes_256_cbc(); break;
	}

	ecb_ctx = EVP_CIPHER_CTX_new();
	cbc_ctx = EVP_CIPHER_CTX_new();

	EVP_EncryptInit_ex(ecb_ctx, ecb, NULL, essiv_key, NULL);
	EVP_CIPHER_CTX_set_padding(ecb_ctx, 0);

	for (i = 0; i < n_sectors; i++) {
		/* IV = AES_ECB(essiv_key, sector_num_le128) */
		uint8_t sector_le[16], iv[16];
		int outl = 16;
		int outl2 = 0;

		sector_to_le128(start_sector + i, sector_le);
		EVP_EncryptUpdate(ecb_ctx, iv, &outl, sector_le, 16);

		EVP_EncryptInit_ex(cbc_ctx, cbc, NULL, key, iv);
		EVP_CIPHER_CTX_set_padding(cbc_ctx, 0);
		EVP_EncryptUpdate(cbc_ctx, out + i * SECTOR_SIZE, &outl2,
				  in  + i * SECTOR_SIZE, SECTOR_SIZE);
	}
	EVP_CIPHER_CTX_free(ecb_ctx);
	EVP_CIPHER_CTX_free(cbc_ctx);
	memset(essiv_key, 0, sizeof(essiv_key));
}

/* ── CLI ──────────────────────────────────────────────────────────────────── */

static const struct option long_opts[] = {
	{ "output",        required_argument, 0, 'o' },
	{ "input",         required_argument, 0, 'i' },
	{ "passphrase",    required_argument, 0, 'p' },
	{ "key-hex",       required_argument, 0, 'x' },
	{ "key-file",      required_argument, 0, 'K' },
	{ "size",          required_argument, 0, 's' },
	{ "cipher",        required_argument, 0, 'c' },
	{ "hash",          required_argument, 0, 'H' },
	{ "key-size",      required_argument, 0, 'k' },
	{ "sector-offset", required_argument, 0, 'O' },
	{ "help",          no_argument,       0, 'h' },
	{ 0 }
};

static void usage(const char *prog)
{
	fprintf(stderr,
		"Usage: %s -o OUT (-p PASS | --key-hex HEX | -K FILE) [OPTIONS]\n"
		"\n"
		"  -o, --output PATH        Output image (must not exist)\n"
		"  -i, --input  PATH        Encrypt existing image (size inferred)\n"
		"  -p, --passphrase TEXT    Derive key from passphrase\n"
		"      --key-hex HEX        Binary key as hex string (dmsetup style)\n"
		"  -K, --key-file PATH      Raw binary key file\n"
		"  -s, --size SIZE          Image size: 64M, 512M, 1G … [64M]\n"
		"  -c, --cipher NAME        aes-xts-plain64 (default) | aes-cbc-essiv:sha256\n"
		"  -H, --hash NAME          sha256 (default) | sha512 | sha1\n"
		"  -k, --key-size BITS      256 or 512 for XTS, 128/192/256 for CBC [512]\n"
		"  -O, --sector-offset N    Starting sector for IV [0]\n",
		prog);
	exit(1);
}

struct args {
	uint64_t    sector_offset;
	const char *output;
	const char *input;
	const char *passphrase;
	const char *key_hex;
	const char *key_file;
	const char *size_str;
	const char *cipher_name;
	const char *hash_name;
	int         key_size_bits;
};

static int parse_args(int argc, char *argv[], struct args *a)
{
	int opt;

	a->sector_offset = 0;
	a->output        = NULL;
	a->input         = NULL;
	a->passphrase    = NULL;
	a->key_hex       = NULL;
	a->key_file      = NULL;
	a->size_str      = NULL;
	a->cipher_name   = "aes-xts-plain64";
	a->hash_name     = "sha256";
	a->key_size_bits = 512;

	while ((opt = getopt_long(argc, argv, "o:i:p:K:s:c:H:k:O:h",
				  long_opts, NULL)) != -1) {
		switch (opt) {
		case 'o': a->output        = optarg;                   break;
		case 'i': a->input         = optarg;                   break;
		case 'p': a->passphrase    = optarg;                   break;
		case 'x': a->key_hex       = optarg;                   break;
		case 'K': a->key_file      = optarg;                   break;
		case 's': a->size_str      = optarg;                   break;
		case 'c': a->cipher_name   = optarg;                   break;
		case 'H': a->hash_name     = optarg;                   break;
		case 'k': a->key_size_bits = atoi(optarg);             break;
		case 'O': a->sector_offset = (uint64_t)atoll(optarg); break;
		default:  usage(argv[0]);
		}
	}

	if (!a->output) {
		fprintf(stderr, "error: -o/--output is required\n");
		return 1;
	}
	if (!a->passphrase && !a->key_hex && !a->key_file) {
		fprintf(stderr, "error: one of -p / --key-hex / -K is required\n");
		return 1;
	}
	return 0;
}

static off_t resolve_image_size(const struct args *a)
{
	if (a->input) {
		struct stat st;
		off_t sz;

		if (stat(a->input, &st) != 0) {
			fprintf(stderr, "error: --input: %s: %s\n",
				a->input, strerror(errno));
			return -1;
		}
		if (st.st_size == 0) {
			fprintf(stderr, "error: --input: file is empty\n");
			return -1;
		}
		if (a->size_str) {
			sz = parse_size(a->size_str);
			if (sz < 0)
				return -1;
			return sz;
		}
		return st.st_size;
	}

	return parse_size(a->size_str ? a->size_str : "64M");
}

static int load_key_hex(const char *key_hex, uint8_t *key, size_t *keylen)
{
	size_t hlen = strlen(key_hex);
	size_t len;
	size_t i;

	if (hlen & 1) {
		fprintf(stderr, "error: --key-hex: odd number of hex digits\n");
		return 1;
	}
	len = hlen / 2;

	if (len > MAX_KEY_BYTES) {
		fprintf(stderr, "error: --key-hex: key too large (max %d bytes)\n",
			MAX_KEY_BYTES);
		return 1;
	}
	for (i = 0; i < len; i++) {
		unsigned byte;

		if (sscanf(key_hex + i * 2, "%02x", &byte) != 1) {
			fprintf(stderr,
				"error: --key-hex: invalid hex at offset %zu\n",
				i * 2);
			return 1;
		}
		key[i] = (uint8_t)byte;
	}
	*keylen = len;
	return 0;
}

static int load_key_file(const char *key_file, uint8_t *key, size_t *keylen)
{
	ssize_t nr;
	int kf;

	kf = open(key_file, O_RDONLY);
	if (kf < 0) {
		fprintf(stderr, "error: --key-file: %s: %s\n",
			key_file, strerror(errno));
		return 1;
	}
	nr = read(kf, key, MAX_KEY_BYTES);
	close(kf);

	if (nr < 0) {
		fprintf(stderr, "error: --key-file: read: %s\n", strerror(errno));
		return 1;
	}
	if (nr == 0) {
		fprintf(stderr, "error: --key-file: file is empty\n");
		return 1;
	}
	*keylen = (size_t)nr;
	return 0;
}

static int load_key_passphrase(const char *passphrase, const char *hash_name,
			       int key_size_bits, uint8_t *key, size_t *keylen)
{
	size_t len;

	if (key_size_bits <= 0) {
		fprintf(stderr, "error: --key-size must be positive\n");
		return 1;
	}
	if (key_size_bits % 8) {
		fprintf(stderr, "error: --key-size must be a multiple of 8\n");
		return 1;
	}
	len = (size_t)(key_size_bits / 8);

	if (len > MAX_KEY_BYTES) {
		fprintf(stderr, "error: --key-size too large\n");
		return 1;
	}
	if (plain_hash_key((const uint8_t *)passphrase, strlen(passphrase),
			   hash_name, key, len) != 0) {
		fprintf(stderr, "error: unknown hash '%s'\n", hash_name);
		return 1;
	}
	*keylen = len;
	return 0;
}

static int validate_cipher(const char *cipher_name, size_t keylen,
			   enum cipher_mode *mode)
{
	if (strcmp(cipher_name, "aes-xts-plain64") == 0) {
		*mode = MODE_XTS;
		if (keylen != 32 && keylen != 64) {
			fprintf(stderr,
				"error: aes-xts-plain64 requires 256 or 512-bit key\n");
			return 1;
		}
		return 0;
	}
	if (strcmp(cipher_name, "aes-cbc-essiv:sha256") == 0) {
		*mode = MODE_CBC_ESSIV;
		if (keylen != 16 && keylen != 24 && keylen != 32) {
			fprintf(stderr,
				"error: aes-cbc-essiv:sha256 requires 128/192/256-bit key\n");
			return 1;
		}
		return 0;
	}
	fprintf(stderr, "error: unknown cipher '%s'\n", cipher_name);
	return 1;
}

static int encrypt_image(const struct args *a, const uint8_t *key, size_t keylen,
			 enum cipher_mode mode, off_t image_size)
{
	uint64_t total_sectors = (uint64_t)(image_size / SECTOR_SIZE);
	uint64_t sector    = a->sector_offset;
	uint64_t remaining = total_sectors;
	int out_fd;
	int in_fd = -1;
	int ret = 1;
	static uint8_t in_buf[BATCH_SECTORS * SECTOR_SIZE];
	static uint8_t out_buf[BATCH_SECTORS * SECTOR_SIZE];

	out_fd = open(a->output, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (out_fd < 0) {
		fprintf(stderr, "error: %s: %s\n", a->output, strerror(errno));
		return 1;
	}

	if (a->input) {
		in_fd = open(a->input, O_RDONLY);
		if (in_fd < 0) {
			fprintf(stderr, "error: %s: %s\n", a->input, strerror(errno));
			goto out;
		}
	}

	fprintf(stderr, "Writing %s (%llu MiB)  source: %s ...\n",
		a->output,
		(unsigned long long)(image_size >> 20),
		a->input ? a->input : "zeros (encrypted)");

	while (remaining > 0) {
		uint64_t n      = remaining < BATCH_SECTORS ? remaining : BATCH_SECTORS;
		size_t   nbytes = (size_t)(n * SECTOR_SIZE);

		if (in_fd >= 0) {
			ssize_t got = read(in_fd, in_buf, nbytes);

			if (got < 0) {
				fprintf(stderr, "error: read failed: %s\n",
					strerror(errno));
				goto out;
			}
			if ((size_t)got < nbytes)
				memset(in_buf + got, 0, nbytes - (size_t)got);
			if (mode == MODE_XTS)
				encrypt_xts(key, keylen, in_buf, out_buf,
					    (size_t)n, sector);
			else
				encrypt_cbc_essiv(key, keylen, in_buf, out_buf,
						  (size_t)n, sector);
			if (write(out_fd, out_buf, nbytes) != (ssize_t)nbytes) {
				fprintf(stderr, "error: write failed: %s\n",
					strerror(errno));
				goto out;
			}
		} else {
			memset(in_buf, 0, nbytes);
			if (mode == MODE_XTS)
				encrypt_xts(key, keylen, in_buf, out_buf,
					    (size_t)n, sector);
			else
				encrypt_cbc_essiv(key, keylen, in_buf, out_buf,
						  (size_t)n, sector);
			if (write(out_fd, out_buf, nbytes) != (ssize_t)nbytes) {
				fprintf(stderr, "error: write failed: %s\n",
					strerror(errno));
				goto out;
			}
		}

		sector    += n;
		remaining -= n;
	}

	fprintf(stderr, "Done.  %s  (%llu bytes, %llu sectors)\n",
		a->output,
		(unsigned long long)image_size,
		(unsigned long long)total_sectors);
	ret = 0;

out:
	if (in_fd >= 0)
		close(in_fd);
	close(out_fd);
	return ret;
}

int main(int argc, char *argv[])
{
	uint8_t key[MAX_KEY_BYTES];
	struct args a;
	size_t keylen = 0;
	off_t image_size;
	enum cipher_mode mode;
	int ret = 1;

	memset(key, 0, sizeof(key));

	if (parse_args(argc, argv, &a))
		return 1;

	image_size = resolve_image_size(&a);
	if (image_size < 0)
		return 1;

	if (image_size % SECTOR_SIZE) {
		fprintf(stderr, "error: image size must be a multiple of %d\n",
			SECTOR_SIZE);
		return 1;
	}

	if (a.key_hex)
		ret = load_key_hex(a.key_hex, key, &keylen);
	else if (a.key_file)
		ret = load_key_file(a.key_file, key, &keylen);
	else
		ret = load_key_passphrase(a.passphrase, a.hash_name,
					  a.key_size_bits, key, &keylen);
	if (ret)
		goto out;

	if (validate_cipher(a.cipher_name, keylen, &mode))
		goto out;

	ret = encrypt_image(&a, key, keylen, mode, image_size);
out:
	memset(key, 0, sizeof(key));
	return ret;
}
