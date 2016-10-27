#include <ruby/ruby.h>
#include "../digest.h"
#include "sha3.c"

#define FOREACH_BITLEN(func)	func(224) func(256) func(384) func(512)

#define SHA3_BLOCK_SIZE(bits) ((1600 - (bits) * 2) / 8)

#define DEFINE_INIT_FUNC(bitlen) \
static int \
rb_digest_sha3_##bitlen##_init(void *ctx) \
{ \
    rhash_sha3_##bitlen##_init(ctx); \
    return 1; \
}

static void
rb_digest_sha3_update(void *ctx, unsigned char *ptr, size_t size)
{
    rhash_sha3_update(ctx, ptr, size);
}

static int
rb_digest_sha3_finish(void *ctx, unsigned char *ptr)
{
    rhash_sha3_final(ctx, ptr);
    return 1;
}

#define DEFINE_ALGO_METADATA(bitlen) \
static const rb_digest_metadata_t sha3_##bitlen = { \
    RUBY_DIGEST_API_VERSION, \
    sha3_##bitlen##_hash_size, \
    SHA3_BLOCK_SIZE(bitlen), \
    sizeof(sha3_ctx), \
    rb_digest_sha3_##bitlen##_init, \
    rb_digest_sha3_update, \
    rb_digest_sha3_finish, \
};

FOREACH_BITLEN(DEFINE_INIT_FUNC)
FOREACH_BITLEN(DEFINE_ALGO_METADATA)

void
Init_sha3(void)
{
    VALUE mDigest, cDigest_Base;
    ID id_metadata;

#define DECLARE_ALGO_CLASS(bitlen) \
    VALUE cDigest_SHA3_##bitlen;

    FOREACH_BITLEN(DECLARE_ALGO_CLASS)

    rb_require("digest");

    id_metadata = rb_intern_const("metadata");

    mDigest = rb_path2class("Digest");
    cDigest_Base = rb_path2class("Digest::Base");

#define DEFINE_ALGO_CLASS(bitlen) \
    cDigest_SHA3_##bitlen = rb_define_class_under(mDigest, "SHA3_" #bitlen, cDigest_Base); \
\
    rb_ivar_set(cDigest_SHA3_##bitlen, id_metadata, \
		Data_Wrap_Struct(0, 0, 0, (void *)&sha3_##bitlen));

#undef RUBY_UNTYPED_DATA_WARNING
#define RUBY_UNTYPED_DATA_WARNING 0
    FOREACH_BITLEN(DEFINE_ALGO_CLASS)
}
