/**********************************************************************

  util.c -

  $Author$
  created at: Fri Mar 10 17:22:34 JST 1995

  Copyright (C) 1993-2008 Yukihiro Matsumoto

**********************************************************************/

#if defined __MINGW32__ || defined __MINGW64__
# define MINGW_HAS_SECURE_API 1
#endif

#include "ruby/internal/config.h"

#include <ctype.h>
#include <errno.h>
#include <float.h>
#include <math.h>
#include <stdio.h>

#ifdef _WIN32
# include "missing/file.h"
#endif

#include "internal.h"
#include "internal/sanitizers.h"
#include "internal/util.h"
#include "ruby/util.h"
#include "ruby_atomic.h"

const char ruby_hexdigits[] = "0123456789abcdef0123456789ABCDEF";
#define hexdigit ruby_hexdigits

unsigned long
ruby_scan_oct(const char *start, size_t len, size_t *retlen)
{
    register const char *s = start;
    register unsigned long retval = 0;
    size_t i;

    for (i = 0; i < len; i++) {
        if ((s[0] < '0') || ('7' < s[0])) {
            break;
        }
        retval <<= 3;
        retval |= *s++ - '0';
    }
    *retlen = (size_t)(s - start);
    return retval;
}

unsigned long
ruby_scan_hex(const char *start, size_t len, size_t *retlen)
{
    register const char *s = start;
    register unsigned long retval = 0;
    signed char d;
    size_t i = 0;

    for (i = 0; i < len; i++) {
        d = ruby_digit36_to_number_table[(unsigned char)*s];
        if (d < 0 || 15 < d) {
            break;
        }
        retval <<= 4;
        retval |= d;
        s++;
    }
    *retlen = (size_t)(s - start);
    return retval;
}

const signed char ruby_digit36_to_number_table[] = {
    /*     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f */
    /*0*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*1*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*2*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*3*/  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,
    /*4*/ -1,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,
    /*5*/ 25,26,27,28,29,30,31,32,33,34,35,-1,-1,-1,-1,-1,
    /*6*/ -1,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,
    /*7*/ 25,26,27,28,29,30,31,32,33,34,35,-1,-1,-1,-1,-1,
    /*8*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*9*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*a*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*b*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*c*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*d*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*e*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    /*f*/ -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
};

NO_SANITIZE("unsigned-integer-overflow", extern unsigned long ruby_scan_digits(const char *str, ssize_t len, int base, size_t *retlen, int *overflow));
unsigned long
ruby_scan_digits(const char *str, ssize_t len, int base, size_t *retlen, int *overflow)
{
    RBIMPL_ASSERT_OR_ASSUME(base >= 2);
    RBIMPL_ASSERT_OR_ASSUME(base <= 36);

    const char *start = str;
    unsigned long ret = 0, x;
    unsigned long mul_overflow = (~(unsigned long)0) / base;

    *overflow = 0;

    if (!len) {
        *retlen = 0;
        return 0;
    }

    do {
        int d = ruby_digit36_to_number_table[(unsigned char)*str++];
        if (d == -1 || base <= d) {
            --str;
            break;
        }
        if (mul_overflow < ret)
            *overflow = 1;
        ret *= base;
        x = ret;
        ret += d;
        if (ret < x)
            *overflow = 1;
    } while (len < 0 || --len);
    *retlen = str - start;
    return ret;
}

unsigned long
ruby_strtoul(const char *str, char **endptr, int base)
{
    int c, b, overflow;
    int sign = 0;
    size_t len;
    unsigned long ret;
    const char *subject_found = str;

    if (base < 0) {
        errno = EINVAL;
        return 0;
    }

    if (base == 1 || 36 < base) {
        errno = EINVAL;
        return 0;
    }

    while ((c = *str) && ISSPACE(c))
        str++;

    if (c == '+') {
        sign = 1;
        str++;
    }
    else if (c == '-') {
        sign = -1;
        str++;
    }

    if (str[0] == '0') {
        subject_found = str+1;
        if (base == 0 || base == 16) {
            if (str[1] == 'x' || str[1] == 'X') {
                b = 16;
                str += 2;
            }
            else {
                b = base == 0 ? 8 : 16;
                str++;
            }
        }
        else {
            b = base;
            str++;
        }
    }
    else {
        b = base == 0 ? 10 : base;
    }

    ret = ruby_scan_digits(str, -1, b, &len, &overflow);

    if (0 < len)
        subject_found = str+len;

    if (endptr)
        *endptr = (char*)subject_found;

    if (overflow) {
        errno = ERANGE;
        return ULONG_MAX;
    }

    if (sign < 0) {
        ret = (unsigned long)(-(long)ret);
        return ret;
    }
    else {
        return ret;
    }
}

#if !defined HAVE_GNU_QSORT_R
#include <sys/types.h>
#include <stdint.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

typedef int (cmpfunc_t)(const void*, const void*, void*);

#if defined HAVE_QSORT_S && defined RUBY_MSVCRT_VERSION
/* In contrast to its name, Visual Studio qsort_s is incompatible with
 * C11 in the order of the comparison function's arguments, and same
 * as BSD qsort_r rather. */
# define qsort_r(base, nel, size, arg, cmp) qsort_s(base, nel, size, cmp, arg)
# define cmp_bsd_qsort cmp_ms_qsort
# define HAVE_BSD_QSORT_R 1
#endif

#if defined HAVE_BSD_QSORT_R
struct bsd_qsort_r_args {
    cmpfunc_t *cmp;
    void *arg;
};

static int
cmp_bsd_qsort(void *d, const void *a, const void *b)
{
    const struct bsd_qsort_r_args *args = d;
    return (*args->cmp)(a, b, args->arg);
}

void
ruby_qsort(void* base, const size_t nel, const size_t size, cmpfunc_t *cmp, void *d)
{
    struct bsd_qsort_r_args args;
    args.cmp = cmp;
    args.arg = d;
    qsort_r(base, nel, size, &args, cmp_bsd_qsort);
}
#elif defined HAVE_QSORT_S
/* C11 qsort_s has the same arguments as GNU's, but uses
 * runtime-constraints handler. */
void
ruby_qsort(void* base, const size_t nel, const size_t size, cmpfunc_t *cmp, void *d)
{
    if (!nel || !size) return;  /* nothing to sort */

    /* get rid of runtime-constraints handler for MT-safeness */
    if (!base || !cmp) return;
    if (nel > RSIZE_MAX || size > RSIZE_MAX) return;

    qsort_s(base, nel, size, cmp, d);
}
# define HAVE_GNU_QSORT_R 1
#else
# define qs6_qsort ruby_qsort
# include "missing/qs6.c"
#endif
#endif /* !HAVE_GNU_QSORT_R */

char *
ruby_getcwd(void)
{
#if defined HAVE_GETCWD
# undef RUBY_UNTYPED_DATA_WARNING
# define RUBY_UNTYPED_DATA_WARNING 0
# if defined NO_GETCWD_MALLOC
    VALUE guard = Data_Wrap_Struct((VALUE)0, NULL, RUBY_DEFAULT_FREE, NULL);
    int size = 200;
    char *buf = xmalloc(size);

    while (!getcwd(buf, size)) {
        int e = errno;
        if (e != ERANGE) {
            xfree(buf);
            DATA_PTR(guard) = NULL;
            rb_syserr_fail(e, "getcwd");
        }
        size *= 2;
        DATA_PTR(guard) = buf;
        buf = xrealloc(buf, size);
    }
# else
    VALUE guard = Data_Wrap_Struct((VALUE)0, NULL, free, NULL);
    char *buf, *cwd = getcwd(NULL, 0);
    DATA_PTR(guard) = cwd;
    if (!cwd) rb_sys_fail("getcwd");
    buf = ruby_strdup(cwd);	/* allocate by xmalloc */
    free(cwd);
# endif
    DATA_PTR(RB_GC_GUARD(guard)) = NULL;
#else
# ifndef PATH_MAX
#  define PATH_MAX 8192
# endif
    char *buf = xmalloc(PATH_MAX+1);

    if (!getwd(buf)) {
        int e = errno;
        xfree(buf);
        rb_syserr_fail(e, "getwd");
    }
#endif
    return buf;
}

void
ruby_each_words(const char *str, void (*func)(const char*, int, void*), void *arg)
{
    const char *end;
    int len;

    if (!str) return;
    for (; *str; str = end) {
        while (ISSPACE(*str) || *str == ',') str++;
        if (!*str) break;
        end = str;
        while (*end && !ISSPACE(*end) && *end != ',') end++;
        len = (int)(end - str);	/* assume no string exceeds INT_MAX */
        (*func)(str, len, arg);
    }
}

#undef strtod
#define strtod ruby_strtod
#undef dtoa
#define dtoa ruby_dtoa
#undef hdtoa
#define hdtoa ruby_hdtoa
#include "missing/dtoa.c"
