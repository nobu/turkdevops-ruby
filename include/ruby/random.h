/**********************************************************************

  ruby/random.h -

  $Author$
  created at: Sat May 31 15:17:36 2008

  Copyright (C) 2008 Yukihiro Matsumoto

**********************************************************************/

#ifndef RUBY_RANDOM_H
#define RUBY_RANDOM_H 1

#include "ruby/ruby.h"

#if defined(__cplusplus)
extern "C" {
#if 0
} /* satisfy cc-mode */
#endif
#endif

RUBY_SYMBOL_EXPORT_BEGIN

typedef struct {
    VALUE seed;
} rb_random_t;

typedef struct {
    void (*init)(rb_random_t *, const uint32_t *, size_t);
    VALUE (*state)(const rb_random_t *);
    int (*left)(const rb_random_t *);
    int (*equal)(const rb_random_t *, const rb_random_t *);
    unsigned int (*genrand_int32)(rb_random_t *);
    void (*bytes)(rb_random_t *, void *, size_t);
    void (*copy)(rb_random_t *, const rb_random_t *);
} rb_random_interface_t;

#define rb_rand_if(obj) \
    ((const rb_random_interface_t *)RTYPEDDATA_TYPE(obj)->data)

#define RB_RANDOM_INTERFACE_DECLARE(prefix) \
    static void prefix##_init(rb_random_t *, const uint32_t *, size_t); \
    static VALUE prefix##_state(const rb_random_t *); \
    static int prefix##_left(const rb_random_t *); \
    static int prefix##_equal(const rb_random_t *, const rb_random_t *); \
    static unsigned int prefix##_genrand_int32(rb_random_t *); \
    static void prefix##_bytes(rb_random_t *, void *, size_t); \
    static void prefix##_copy(rb_random_t *, const rb_random_t *); \
    /* end */

#define RB_RANDOM_INTERFACE_DEFINE(prefix) \
    prefix##_init, \
    prefix##_state, \
    prefix##_left, \
    prefix##_equal, \
    prefix##_genrand_int32, \
    prefix##_bytes, \
    prefix##_copy, \
    /* end */

void rb_random_mark(void *ptr);
double rb_int_pair_to_real_exclusive(uint32_t a, uint32_t b);
double rb_int_pair_to_real_inclusive(uint32_t a, uint32_t b);
void rb_rand_bytes_int32(const rb_random_interface_t *, rb_random_t *, void *, size_t);
RUBY_EXTERN const rb_data_type_t rb_random_data_type;

RUBY_SYMBOL_EXPORT_END

#if defined(__cplusplus)
#if 0
{ /* satisfy cc-mode */
#endif
}  /* extern "C" { */
#endif

#endif /* RUBY_RANDOM_H */
