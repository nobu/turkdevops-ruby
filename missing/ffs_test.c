#define test_ffs(func, argtype) do { \
    extern int func(argtype); \
    int result = func(0); \
    printf(#func "(0) = %d\n", result); \
    if (result != 0) ok = false; \
    for (int i = 0; i < (int)(sizeof(argtype) * CHAR_BIT); ++i) { \
        result = func((argtype)1 << i); \
        printf(#func "(1<<%d) = %d\n", i, result); \
        if (result != i + 1) ok = false; \
    } \
} while (0)

int main(void)
{
    bool ok = true;

    test_ffs(ffs, int);
    test_ffs(ffsl, long);
    test_ffs(ffsll, long long);
#ifdef HAVE_INT128_T
    test_ffs(ffs128, int128_t);
#endif

    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
