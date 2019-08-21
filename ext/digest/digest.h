/************************************************

  digest.h - header file for ruby digest modules

  $Author$
  created at: Fri May 25 08:54:56 JST 2001


  Copyright (C) 2001-2006 Akinori MUSHA

  $RoughId: digest.h,v 1.3 2001/07/13 15:38:27 knu Exp $
  $Id$

************************************************/

#include "ruby.h"

#define RUBY_DIGEST_API_VERSION	3

typedef int (*rb_digest_hash_init_func_t)(void *);
typedef void (*rb_digest_hash_update_func_t)(void *, unsigned char *, size_t);
typedef int (*rb_digest_hash_finish_func_t)(void *, unsigned char *);

typedef struct {
    int api_version;
    size_t digest_len;
    size_t block_len;
    size_t ctx_size;
    rb_digest_hash_init_func_t init_func;
    rb_digest_hash_update_func_t update_func;
    rb_digest_hash_finish_func_t finish_func;
} rb_digest_metadata_t;

#define DEFINE_UPDATE_FUNC_FOR_UINT(name) \
void \
rb_digest_##name##_update(void *ctx, unsigned char *ptr, size_t size) \
{ \
    const unsigned int stride = 16384; \
 \
    for (; size > stride; size -= stride, ptr += stride) { \
	name##_Update(ctx, ptr, stride); \
    } \
    if (size > 0) name##_Update(ctx, ptr, size); \
}

#define DEFINE_FINISH_FUNC_FROM_FINAL(name) \
int \
rb_digest_##name##_finish(void *ctx, unsigned char *ptr) \
{ \
    return name##_Final(ptr, ctx); \
}

static inline VALUE
rb_digest_namespace(void)
{
    rb_require("digest");
    return rb_path2class("Digest");
}

static inline ID
rb_id_metadata(void)
{
    return rb_intern_const("metadata");
}

#define DIGEST_METADATA_NAME "Digest::metadata"

static inline VALUE
rb_digest_new_class(VALUE mDigest, ID id_metadata, const char *name, const rb_digest_metadata_t *metadata)
{
    VALUE c, obj;
    const rb_data_type_t *type = 0;

    obj = rb_ivar_get(mDigest, id_metadata);
    if (!RB_TYPE_P(obj, T_DATA)) {
        rb_check_type(obj, T_DATA);
    }
    if (!RTYPEDDATA_P(obj) || !(type = RTYPEDDATA_TYPE(obj)) ||
        strcmp(type->wrap_struct_name, DIGEST_METADATA_NAME)) {
        rb_raise(rb_eRuntimeError, "invalid Digiest::metadata");
    }
    c = rb_define_class_under(mDigest, name, (VALUE)RTYPEDDATA_DATA(obj));
    rb_ivar_set(c, id_metadata, TypedData_Wrap_Struct(0, type, (void*)metadata));
    return c;
}

#define DEFINE_DIGEST_CLASS(name, meta) \
    rb_digest_new_class(rb_digest_namespace(), rb_id_metadata(), name, &(meta))
#define DEFINE_DIGEST_CLASS_UNDER(name, meta) \
    rb_digest_new_class(mDigest, id_metadata, name, &meta)
