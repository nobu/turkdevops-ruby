#include <ruby/ruby.h>
#include "../digest.h"
#include "blake2s.h"
# define blake2s_outlen 32
#if defined HAVE_UINT64_T && SIZEOF_UINT64_T > 0
# include "blake2b.h"
# define blake2b_outlen 64
# define FOREACH_BLAKE2(func)	func(BLAKE2s, blake2s) func(BLAKE2b, blake2b)
#else
# define FOREACH_BLAKE2(func)	func(BLAKE2s, blake2s)
#endif

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
};

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
    }

#undef RUBY_UNTYPED_DATA_WARNING
#define RUBY_UNTYPED_DATA_WARNING 0
    FOREACH_BLAKE2(DEFINE_ALGO_CLASS);

    rb_define_const(mDigest, "BLAKE2", c);
}
