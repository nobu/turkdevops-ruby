#include <ruby/ruby.h>
#include "../digest.h"
#include "blake2s.h"
# define blake2s_outlen 32
struct digest_blake2s {
    blake2s_ctx ctx;
    size_t keylen;
    uint8_t key[32];
};

#if defined HAVE_UINT64_T && SIZEOF_UINT64_T > 0
# include "blake2b.h"
# define blake2b_outlen 64
struct digest_blake2b {
    blake2b_ctx ctx;
    size_t keylen;
    uint8_t key[64];
};
# define FOREACH_BLAKE2(func)	func(BLAKE2s, blake2s) func(BLAKE2b, blake2b)
#else
# define FOREACH_BLAKE2(func)	func(BLAKE2s, blake2s)
#endif

typedef int (*blake2_init_func)(void *, size_t, const void *, size_t);

#define DEFINE_BLAKE2(algo, name) \
int \
rb_digest_##name##_init(void *ctx) \
{ \
    return name##_init(ctx, name##_outlen, NULL, 0) == 0; \
} \
 \
void \
rb_digest_##name##_update(void *ctx, unsigned char *ptr, size_t size) \
{ \
    name##_update(ctx, ptr, size); \
} \
 \
int \
rb_digest_##name##_finish(void *ctx, unsigned char *ptr) \
{ \
    name##_final(ctx, ptr); \
    return 1; \
} \
 \
static const rb_digest_metadata_t name##_type = { \
    RUBY_DIGEST_API_VERSION, \
    name##_outlen, name##_outlen, \
    sizeof(name##_ctx), \
    rb_digest_##name##_init, \
    rb_digest_##name##_update, \
    rb_digest_##name##_finish, \
}; \
 \
static VALUE \
name##_initialize(int argc, VALUE *argv, VALUE self) \
{ \
    struct digest_##name *p = DATA_PTR(self); \
    name##_ctx *ctx = &p->ctx; \
    blake2_initialize(argc, argv, ctx, \
		      (blake2_init_func)name##_init, \
		      name##_outlen, \
		      p->key, &p->keylen); \
    return self; \
} \
 \
static VALUE \
name##_finish(VALUE self) \
{ \
    struct digest_##name *p = DATA_PTR(self); \
    name##_ctx *ctx = &p->ctx; \
    return blake2_finish(ctx, &name##_type, ctx->outlen); \
} \
 \
static VALUE \
name##_digest_length(VALUE self) \
{ \
    struct digest_##name *p = DATA_PTR(self); \
    name##_ctx *ctx = &p->ctx; \
    return SIZET2NUM(ctx->outlen); \
} \
 \
static VALUE \
name##_reset(VALUE self) \
{ \
    struct digest_##name *p = DATA_PTR(self); \
    name##_ctx *ctx = &p->ctx; \
    return name##_init(ctx, ctx->outlen, p->key, p->keylen); \
}

static void
blake2_initialize(int argc, VALUE *argv, void *ctx,
		  blake2_init_func init, size_t outlen,
		  uint8_t *savekey, size_t *savekeylen)
{
    if (rb_check_arity(argc, 0, 2) > 0) {
	VALUE key = Qnil;
	const void *keyptr = NULL;
	long keylen = 0;
	outlen = NUM2SIZET(argv[0]);
	if (argc > 1 && !NIL_P(key = argv[1])) {
	    StringValue(key);
	    RSTRING_GETMEM(key, keyptr, keylen);
	}
	if (init(ctx, outlen, keyptr, keylen)) {
	    rb_raise(rb_eArgError, "invalid arguments: %ld, %"PRIsVALUE,
		     outlen, key);
	}
	*savekeylen = (size_t)keylen;
	if (keylen > 0) {
	    memcpy(savekey, keyptr, keylen);
	    RB_GC_GUARD(key);
	}
    }
}

static VALUE
blake2_finish(void *pctx, const rb_digest_metadata_t *algo, size_t outlen)
{
    VALUE str = rb_str_new(0, outlen);

    algo->finish_func(pctx, (unsigned char *)RSTRING_PTR(str));
    algo->init_func(pctx);

    return str;
}

FOREACH_BLAKE2(DEFINE_BLAKE2)

void
Init_blake2(void)
{
    VALUE mDigest, cDigest_Base, c;
    ID id_metadata;

    rb_require("digest");

    id_metadata = rb_intern_const("metadata");

#if 0
    mDigest = rb_define_module("Digest"); /* let rdoc know */
#endif
    mDigest = rb_path2class("Digest");
    cDigest_Base = rb_path2class("Digest::Base");

#define DEFINE_ALGO_CLASS(algo, name) { \
	VALUE cDigest_##algo; \
	VALUE metadata = Data_Wrap_Struct(0, 0, 0, (void *)&name##_type); \
	c = rb_define_class_under(mDigest, #algo, cDigest_Base); \
	cDigest_##algo = c; \
	rb_ivar_set(c, id_metadata, metadata); \
	rb_define_method(c, "initialize", name##_initialize, -1); \
	rb_define_private_method(c, "finish", name##_finish, 0); \
	rb_define_method(c, "digest_length", name##_digest_length, 0); \
	rb_define_method(c, "reset", name##_reset, 0); \
    }

#undef RUBY_UNTYPED_DATA_WARNING
#define RUBY_UNTYPED_DATA_WARNING 0
    FOREACH_BLAKE2(DEFINE_ALGO_CLASS);

    rb_define_const(mDigest, "BLAKE2", c);
}
