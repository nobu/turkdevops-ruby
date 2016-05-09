#include "ruby/random.h"

#define KEYSTREAM_ONLY
#include "chacha_private.h"

#ifndef numberof
# define numberof(array) (sizeof(array)/sizeof((array)[0]))
#endif
#ifndef FALSE
# define FALSE 0
#endif
#ifndef TRUE
# define TRUE 1
#endif

#define KEYSZ	(256/8)
#define IVSZ	8
#define BLOCKSZ	64
#define RSBUFSZ	(16*BLOCKSZ)

typedef struct {
    chacha_ctx rs_chacha;    /* chacha context for random keystream */
    uint16_t rs_have;	     /* valid bytes at end of rs_buf */
    uint8_t rs_buf[RSBUFSZ];  /* keystream blocks */
} rs_t;

typedef struct {
    rb_random_t base;
    rs_t rs;
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
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;

    if (len < KEYSZ + IVSZ)
	return;

    chacha_keysetup(&rs->rs_chacha, buf, KEYSZ * 8, 0);
    chacha_ivsetup(&rs->rs_chacha, buf + KEYSZ);
}

static void
rs_rekey(rb_random_t *rnd, const uint8_t *dat, size_t datlen)
{
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;

#ifndef KEYSTREAM_ONLY
    memset(rs->rs_buf, 0, sizeof(rs->rs_buf));
#endif
    /* fill rs_buf with the keystream */
    chacha_encrypt_bytes(&rs->rs_chacha, rs->rs_buf,
			 rs->rs_buf, sizeof(rs->rs_buf));
    /* mix in optional user provided data */
    if (dat) {
	size_t i, m;

	m = minimum(datlen, KEYSZ + IVSZ);
	for (i = 0; i < m; i++)
	    rs->rs_buf[i] ^= dat[i];
    }
    /* immediately reinit for backtracking resistance */
    rs_init0(rnd, rs->rs_buf, KEYSZ + IVSZ);
    memset(rs->rs_buf, 0, KEYSZ + IVSZ);
    rs->rs_have = sizeof(rs->rs_buf) - KEYSZ - IVSZ;
}

static void
rs_init(rb_random_t *rnd, const uint32_t *buf, size_t len)
{
    rs_rekey(rnd, (const uint8_t *)buf, len * sizeof(*buf));
}

static void
rs_bytes(rb_random_t *rnd, void *p, size_t n)
{
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;
    uint8_t *buf = p;
    uint8_t *keystream;
    size_t m;

    while (n > 0) {
	if (rs->rs_have > 0) {
	    m = minimum(n, rs->rs_have);
	    keystream = rs->rs_buf + sizeof(rs->rs_buf)
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
    rs_t *rs = &((rand_chacha_t *)rnd)->rs;
    uint8_t *keystream;
    uint32_t val;

    if (rs->rs_have < sizeof(val))
	rs_rekey(rnd, NULL, 0);
    keystream = rs->rs_buf + sizeof(rs->rs_buf) - rs->rs_have;
    memcpy(&val, keystream, sizeof(val));
    memset(keystream, 0, sizeof(val));
    rs->rs_have -= sizeof(val);
    return val;
}

static VALUE
rs_state(const rb_random_t *rnd)
{
    chacha_ctx *ctx = &((rand_chacha_t *)rnd)->rs.rs_chacha;
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
    if (memcmp(r1->rs.rs_chacha.input,
	       r2->rs.rs_chacha.input,
	       sizeof(r1->rs.rs_chacha.input)))
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
