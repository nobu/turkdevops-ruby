#include "ruby/random.h"

#ifndef numberof
# define numberof(array) (sizeof(array)/sizeof((array)[0]))
#endif
#ifndef FALSE
# define FALSE 0
#endif
#ifndef TRUE
# define TRUE 1
#endif

/*
  chacha-merged.c version 20080118
  D. J. Bernstein
  Public domain.
*/

/* $OpenBSD$ */

#define KEYSTREAM_ONLY

typedef struct {
    uint32_t input[16]; /* could be compressed */
} chacha_ctx;

#define U8C(v) (v##U)
#define U32C(v) (v##U)

#define U8V(v) ((uint8_t)(v) & U8C(0xFF))
#define U32V(v) ((uint32_t)(v) & U32C(0xFFFFFFFF))

#define ROTL32(v, n)				\
    (U32V((v) << (n)) | ((v) >> (32 - (n))))

#define U8TO32_LITTLE(p)			\
    (((uint32_t)((p)[0])      ) |		\
     ((uint32_t)((p)[1]) <<  8) |		\
     ((uint32_t)((p)[2]) << 16) |		\
     ((uint32_t)((p)[3]) << 24))

#define U32TO8_LITTLE(p, v)			\
    do {					\
	(p)[0] = U8V((v)      );		\
	(p)[1] = U8V((v) >>  8);		\
	(p)[2] = U8V((v) >> 16);		\
	(p)[3] = U8V((v) >> 24);		\
    } while (0)

#define ROTATE(v, c) (ROTL32(v, c))
#define XOR(v, w) ((v) ^ (w))
#define PLUS(v, w) (U32V((v) + (w)))
#define PLUSONE(v) (PLUS((v), 1))

#define QUARTERROUND(a, b, c, d)		\
    a = PLUS(a, b); d = ROTATE(XOR(d, a), 16);	\
    c = PLUS(c, d); b = ROTATE(XOR(b, c), 12);	\
    a = PLUS(a, b); d = ROTATE(XOR(d, a), 8);	\
    c = PLUS(c, d); b = ROTATE(XOR(b, c), 7);

static const char sigma_tau[][16] = {
    "expand 32-byte k",
    "expand 16-byte k",
};
#define sigma sigma_tau[0]
#define tau sigma_tau[1]

static void
chacha_keysetup(chacha_ctx *x, const uint8_t *k, uint32_t kbits, uint32_t ivbits)
{
    const char *constants;

    x->input[4] = U8TO32_LITTLE(k + 0);
    x->input[5] = U8TO32_LITTLE(k + 4);
    x->input[6] = U8TO32_LITTLE(k + 8);
    x->input[7] = U8TO32_LITTLE(k + 12);
    if (kbits == 256) { /* recommended */
	k += 16;
	constants = sigma;
    }
    else { /* kbits == 128 */
	constants = tau;
    }
    x->input[8] = U8TO32_LITTLE(k + 0);
    x->input[9] = U8TO32_LITTLE(k + 4);
    x->input[10] = U8TO32_LITTLE(k + 8);
    x->input[11] = U8TO32_LITTLE(k + 12);
    x->input[0] = U8TO32_LITTLE(constants + 0);
    x->input[1] = U8TO32_LITTLE(constants + 4);
    x->input[2] = U8TO32_LITTLE(constants + 8);
    x->input[3] = U8TO32_LITTLE(constants + 12);
}

static void
chacha_ivsetup(chacha_ctx *x, const uint8_t *iv)
{
    x->input[12] = 0;
    x->input[13] = 0;
    x->input[14] = U8TO32_LITTLE(iv + 0);
    x->input[15] = U8TO32_LITTLE(iv + 4);
}

static void
chacha_encrypt_bytes(chacha_ctx *x, const uint8_t *m, uint8_t *c, uint32_t bytes)
{
    uint32_t x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    uint32_t j0, j1, j2, j3, j4, j5, j6, j7, j8, j9, j10, j11, j12, j13, j14, j15;
    uint8_t *ctarget = NULL;
    uint8_t tmp[64];
    u_int i;

    if (!bytes) return;

    j0 = x->input[0];
    j1 = x->input[1];
    j2 = x->input[2];
    j3 = x->input[3];
    j4 = x->input[4];
    j5 = x->input[5];
    j6 = x->input[6];
    j7 = x->input[7];
    j8 = x->input[8];
    j9 = x->input[9];
    j10 = x->input[10];
    j11 = x->input[11];
    j12 = x->input[12];
    j13 = x->input[13];
    j14 = x->input[14];
    j15 = x->input[15];

    for (;;) {
	if (bytes < 64) {
	    for (i = 0;i < bytes;++i) tmp[i] = m[i];
	    m = tmp;
	    ctarget = c;
	    c = tmp;
	}
	x0 = j0;
	x1 = j1;
	x2 = j2;
	x3 = j3;
	x4 = j4;
	x5 = j5;
	x6 = j6;
	x7 = j7;
	x8 = j8;
	x9 = j9;
	x10 = j10;
	x11 = j11;
	x12 = j12;
	x13 = j13;
	x14 = j14;
	x15 = j15;
	for (i = 20;i > 0;i -= 2) {
	    QUARTERROUND( x0, x4, x8, x12);
	    QUARTERROUND( x1, x5, x9, x13);
	    QUARTERROUND( x2, x6, x10, x14);
	    QUARTERROUND( x3, x7, x11, x15);
	    QUARTERROUND( x0, x5, x10, x15);
	    QUARTERROUND( x1, x6, x11, x12);
	    QUARTERROUND( x2, x7, x8, x13);
	    QUARTERROUND( x3, x4, x9, x14);
	}
	x0 = PLUS(x0, j0);
	x1 = PLUS(x1, j1);
	x2 = PLUS(x2, j2);
	x3 = PLUS(x3, j3);
	x4 = PLUS(x4, j4);
	x5 = PLUS(x5, j5);
	x6 = PLUS(x6, j6);
	x7 = PLUS(x7, j7);
	x8 = PLUS(x8, j8);
	x9 = PLUS(x9, j9);
	x10 = PLUS(x10, j10);
	x11 = PLUS(x11, j11);
	x12 = PLUS(x12, j12);
	x13 = PLUS(x13, j13);
	x14 = PLUS(x14, j14);
	x15 = PLUS(x15, j15);

#ifndef KEYSTREAM_ONLY
	x0 = XOR(x0, U8TO32_LITTLE(m + 0));
	x1 = XOR(x1, U8TO32_LITTLE(m + 4));
	x2 = XOR(x2, U8TO32_LITTLE(m + 8));
	x3 = XOR(x3, U8TO32_LITTLE(m + 12));
	x4 = XOR(x4, U8TO32_LITTLE(m + 16));
	x5 = XOR(x5, U8TO32_LITTLE(m + 20));
	x6 = XOR(x6, U8TO32_LITTLE(m + 24));
	x7 = XOR(x7, U8TO32_LITTLE(m + 28));
	x8 = XOR(x8, U8TO32_LITTLE(m + 32));
	x9 = XOR(x9, U8TO32_LITTLE(m + 36));
	x10 = XOR(x10, U8TO32_LITTLE(m + 40));
	x11 = XOR(x11, U8TO32_LITTLE(m + 44));
	x12 = XOR(x12, U8TO32_LITTLE(m + 48));
	x13 = XOR(x13, U8TO32_LITTLE(m + 52));
	x14 = XOR(x14, U8TO32_LITTLE(m + 56));
	x15 = XOR(x15, U8TO32_LITTLE(m + 60));
#endif

	j12 = PLUSONE(j12);
	if (!j12) {
	    j13 = PLUSONE(j13);
	    /* stopping at 2^70 bytes per nonce is user's responsibility */
	}

	U32TO8_LITTLE(c + 0, x0);
	U32TO8_LITTLE(c + 4, x1);
	U32TO8_LITTLE(c + 8, x2);
	U32TO8_LITTLE(c + 12, x3);
	U32TO8_LITTLE(c + 16, x4);
	U32TO8_LITTLE(c + 20, x5);
	U32TO8_LITTLE(c + 24, x6);
	U32TO8_LITTLE(c + 28, x7);
	U32TO8_LITTLE(c + 32, x8);
	U32TO8_LITTLE(c + 36, x9);
	U32TO8_LITTLE(c + 40, x10);
	U32TO8_LITTLE(c + 44, x11);
	U32TO8_LITTLE(c + 48, x12);
	U32TO8_LITTLE(c + 52, x13);
	U32TO8_LITTLE(c + 56, x14);
	U32TO8_LITTLE(c + 60, x15);

	if (bytes <= 64) {
	    if (bytes < 64) {
		for (i = 0;i < bytes;++i) ctarget[i] = c[i];
	    }
	    x->input[12] = j12;
	    x->input[13] = j13;
	    return;
	}
	bytes -= 64;
	c += 64;
#ifndef KEYSTREAM_ONLY
	m += 64;
#endif
    }
}

#define KEYSZ	32
#define IVSZ	8
#define BLOCKSZ	64
#define RSBUFSZ	(16*BLOCKSZ)

typedef struct {
    uint16_t rs_have;	     /* valid bytes at end of rs_buf */
#if 0
    uint16_t rs_count;	     /* bytes till reseed */
#endif
} rs_t;

typedef struct {
    chacha_ctx rs_chacha;    /* chacha context for random keystream */
    uint8_t rs_buf[RSBUFSZ];  /* keystream blocks */
} rsx_t;

typedef struct {
    rb_random_t base;
    rs_t rs;
    rsx_t rsx;
} rand_chacha_t;

RB_RANDOM_INTERFACE_DECLARE(rs)
static const rb_random_interface_t random_chacha_if = {
    RB_RANDOM_INTERFACE_DEFINE(rs)
};

static size_t
random_chacha_memsize(const void *ptr)
{
    return sizeof(rand_chacha_t);
}

static const rb_data_type_t random_chacha_type = {
    "random/ChaCha",
    {
	rb_random_mark,
	RUBY_TYPED_DEFAULT_FREE,
	random_chacha_memsize,
    },
    &rb_random_data_type,
    (void *)&random_chacha_if,
    RUBY_TYPED_FREE_IMMEDIATELY
};

static size_t
minimum(size_t x, size_t y)
{
    return x < y ? x : y;
}

static VALUE
rs_alloc(VALUE klass)
{
    rand_chacha_t *rnd;
    VALUE obj = TypedData_Make_Struct(klass, rand_chacha_t, &random_chacha_type, rnd);
    rnd->base.seed = INT2FIX(0);
    return obj;
}

static void
rs_init0(rb_random_t *rnd, const uint8_t *buf, size_t len)
{
    rsx_t *rsx = &((rand_chacha_t *)rnd)->rsx;

    if (len < KEYSZ + IVSZ)
	return;

    chacha_keysetup(&rsx->rs_chacha, buf, KEYSZ * 8, 0);
    chacha_ivsetup(&rsx->rs_chacha, buf + KEYSZ);
}

static void
rs_rekey(rb_random_t *rnd, const uint8_t *dat, size_t datlen)
{
    rsx_t *rsx = &((rand_chacha_t *)rnd)->rsx;
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;

#ifndef KEYSTREAM_ONLY
    memset(rsx->rs_buf, 0, sizeof(rsx->rs_buf));
#endif
    /* fill rs_buf with the keystream */
    chacha_encrypt_bytes(&rsx->rs_chacha, rsx->rs_buf,
			 rsx->rs_buf, sizeof(rsx->rs_buf));
    /* mix in optional user provided data */
    if (dat) {
	size_t i, m;

	m = minimum(datlen, KEYSZ + IVSZ);
	for (i = 0; i < m; i++)
	    rsx->rs_buf[i] ^= dat[i];
    }
    /* immediately reinit for backtracking resistance */
    rs_init0(rnd, rsx->rs_buf, KEYSZ + IVSZ);
    memset(rsx->rs_buf, 0, KEYSZ + IVSZ);
    rs->rs_have = sizeof(rsx->rs_buf) - KEYSZ - IVSZ;
}

static void
rs_init(rb_random_t *rnd, const uint32_t *buf, size_t len)
{
    rs_rekey(rnd, (const uint8_t *)buf, len * sizeof(*buf));
    ((rand_chacha_t *)rnd)->rs.rs_have = 0;
}

static void
rs_bytes(rb_random_t *rnd, void *p, size_t n)
{
    rsx_t *rsx = &((rand_chacha_t *)rnd)->rsx;
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;
    uint8_t *buf = p;
    uint8_t *keystream;
    size_t m;

    while (n > 0) {
	if (rs->rs_have > 0) {
	    m = minimum(n, rs->rs_have);
	    keystream = rsx->rs_buf + sizeof(rsx->rs_buf)
		- rs->rs_have;
	    memcpy(buf, keystream, m);
	    memset(keystream, 0, m);
	    buf += m;
	    n -= m;
	    rs->rs_have -= m;
	}
	if (rs->rs_have == 0)
	    rs_rekey(rnd, NULL, 0);
    }
}

static uint32_t
rs_genrand_int32(rb_random_t *rnd)
{
    rsx_t *rsx = &((rand_chacha_t *)rnd)->rsx;
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;
    uint8_t *keystream;
    uint32_t val;

    if (rs->rs_have < sizeof(val))
	rs_rekey(rnd, NULL, 0);
    keystream = rsx->rs_buf + sizeof(rsx->rs_buf) - rs->rs_have;
    memcpy(&val, keystream, sizeof(val));
    memset(keystream, 0, sizeof(val));
    rs->rs_have -= sizeof(val);
    return val;
}

static VALUE
rs_state(const rb_random_t *rnd)
{
    chacha_ctx *ctx = &((rand_chacha_t *)rnd)->rsx.rs_chacha;
    return rb_integer_unpack(ctx->input, numberof(ctx->input),
        sizeof(*ctx->input), 0,
        INTEGER_PACK_LSWORD_FIRST|INTEGER_PACK_NATIVE_BYTE_ORDER);
}

static int
rs_left(const rb_random_t *rnd)
{
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;
    return rs->rs_have;
}

static int
rs_equal(const rb_random_t *rnd1, const rb_random_t *rnd2)
{
    const rand_chacha_t *r1 = (const rand_chacha_t *)rnd1;
    const rand_chacha_t *r2 = (const rand_chacha_t *)rnd2;
    if (memcmp(r1->rsx.rs_chacha.input,
	       r2->rsx.rs_chacha.input,
	       sizeof(r1->rsx.rs_chacha.input)))
	return FALSE;
    if (r1->rs.rs_have != r2->rs.rs_have) return FALSE;
    return TRUE;
}

static void
rs_copy(rb_random_t *rnd1, const rb_random_t *rnd2)
{
    rand_chacha_t *r1 = (rand_chacha_t *)rnd1;
    const rand_chacha_t *r2 = (const rand_chacha_t *)rnd2;

    *r1 = *r2;
}

void
Init_chacha(void)
{
    VALUE c = rb_define_class_under(rb_cRandom, "ChaCha", rb_cRandom);
    rb_define_alloc_func(c, rs_alloc);
}
