#ifndef FFS_H
#define FFS_H 1
/* ffs.c - find first set bit */
/* ffs() is defined by Single Unix Specification. */

#include "ruby.h"

#define FFS_BITS(n) \
    ((sizeof(ffs_arg_t) * CHAR_BIT > (n)) ? (n) : 0)
#define FFS_MASK(n) (~(~(ffs_arg_t)0U << FFS_BITS(n)))
#define FFS_N(x, n) \
    ((((x) & FFS_MASK(n)) == 0) ? ((x) >>= FFS_BITS(n), FFS_BITS(n)) : 0)

/* may be unrolled */
#define FFS_LOOP(x, r) \
    for (unsigned int w = ((r) = 1, sizeof(ffs_arg_t) * CHAR_BIT); \
         (w >>= 1) > 0; ) { \
        (r) += FFS_N(x, w); \
    }

#define FFS_BODY(arg_type, arg) do { \
    typedef arg_type ffs_arg_t; \
    ffs_arg_t x = (ffs_arg_t)(arg); \
    int r; \
    \
    if (x == 0) return 0; \
    FFS_LOOP(x, r); \
    \
    return r; \
} while (0)
#endif
