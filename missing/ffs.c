/* ffs.c - find first set bit */
/* ffs() is defined by Single Unix Specification. */

#include "ruby.h"

#define FFS_BITS(n) \
    ((sizeof(ffs_arg_t) * CHAR_BIT > (n)) ? (n) : 0)
#define FFS_MASK(n) (~(~(ffs_arg_t)0U << FFS_BITS(n)))
#define FFS_N(x, n) \
    ((((x) & FFS_MASK(n)) == 0) ? ((x) >>= FFS_BITS(n), FFS_BITS(n)) : 0)

int ffs(int arg)
{
    typedef unsigned int ffs_arg_t;
    ffs_arg_t x = (ffs_arg_t)arg;
    int r;

    if (x == 0)
        return 0;

    r = 1;
    r += FFS_N(x, 1<<8);
    r += FFS_N(x, 1<<7);
    r += FFS_N(x, 1<<6);
    r += FFS_N(x, 1<<5);
    r += FFS_N(x, 1<<4);
    r += FFS_N(x, 1<<3);
    r += FFS_N(x, 1<<2);
    r += FFS_N(x, 1<<1);
    r += FFS_N(x, 1<<0);

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

    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
#endif
