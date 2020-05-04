#include <string.h>

char *
stpncpy(char *dst, const char *src, size_t len)
{
    char last = '\0';
    while (len-- > 0) {
        if (!(*dst++ = *src++)) {
            if (len > 0) memset(dst, '\0', len);
            --dst;
            break;
        }
    }
    return dst;
}
