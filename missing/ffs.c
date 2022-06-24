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

int ffs(int arg)
{
    typedef unsigned int ffs_arg_t;
    ffs_arg_t x = (ffs_arg_t)arg;
    int r;

    if (x == 0)
        return 0;

    FFS_LOOP(x, r);

    return r;
}

int ffsl(long arg)
{
    typedef unsigned long ffs_arg_t;
    ffs_arg_t x = (ffs_arg_t)arg;
    int r;

    if (x == 0)
        return 0;

    FFS_LOOP(x, r);

    return r;
}

#ifdef TEST_FFS
#define test_ffs(func, argtype) do { \
    printf(#func "(0) = %d\n", func(0)); \
    for (int i = 0; i < (int)(sizeof(argtype) * CHAR_BIT); ++i) { \
        int result = func((argtype)1 << i); \
        printf(#func "(1<<%d) = %d\n", i, result); \
        if (result != i + 1) ok = false; \
    } \
} while (0)

int main(void)
{
    bool ok = true;

    test_ffs(ffs, int);
    test_ffs(ffsl, long);

    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
#endif
