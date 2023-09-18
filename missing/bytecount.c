#include <stddef.h>
#include <stdint.h>

static size_t
naive_bytecount(const void *haystack, int n, size_t len)
{
    size_t count = 0;
    const uint8_t *ptr = haystack;
    const uint8_t *end_ptr = ptr + len;

    while (ptr < end_ptr) {
        if (*ptr == (uint8_t)n) {
            count++;
        }
        ptr++;
    }

    return count;
}

#ifdef __SSE4_2__
#include <smmintrin.h>

static const uint8_t MASK[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
};

static __m128i
mm_from_offset(const uint8_t *haystack, size_t offset)
{
    return _mm_loadu_si128((__m128i *)(haystack + offset));
}

static size_t
sum(__m128i *u8s)
{
    __m128i sums = _mm_sad_epu8(*u8s, _mm_setzero_si128());
    return (size_t) _mm_extract_epi32(sums, 0) + _mm_extract_epi32(sums, 2);
}

static size_t
mm_bytecount(const void *haystack, int n, size_t len)
{
    const uint8_t *ptr = haystack;
    size_t offset = 0;
    size_t count = 0;

    const __m128i needles = _mm_set1_epi8((uint8_t)n);

    // 4080
    while (len >= offset + 16 * 255) {
        __m128i counts = _mm_setzero_si128();

        for (size_t i=0; i < 255; i++) {
            counts = _mm_sub_epi8(
                counts,
                _mm_cmpeq_epi8(mm_from_offset(ptr, offset), needles)
                );
            offset += 16;
        }

        count += sum(&counts);
    }

    // 2048
    if (len >= offset + 16 * 128) {
        __m128i counts = _mm_setzero_si128();

        for (size_t i=0; i < 128; i++) {
            counts = _mm_sub_epi8(
                counts,
                _mm_cmpeq_epi8(mm_from_offset(ptr, offset), needles)
                );
            offset += 16;
        }

        count += sum(&counts);
    }

    // 16
    __m128i counts = _mm_setzero_si128();
    for (size_t i=0; i < ((len - offset) / 16); i++) {
        counts = _mm_sub_epi8(
            counts,
            _mm_cmpeq_epi8(mm_from_offset(ptr, offset + i * 16), needles)
            );
    }

    if (len % 16 != 0) {
        counts = _mm_sub_epi8(
            counts,
            _mm_and_si128(
                _mm_cmpeq_epi8(mm_from_offset(ptr, len - 16), needles),
                mm_from_offset(MASK, len % 16)
                )
            );
    }
    count += sum(&counts);

    return count;
}
# define USE_MM_BYTECOUNT 1
#else
# define USE_MM_BYTECOUNT 0
# define mm_bytecount(haystack, n, len) (assert(0), 0)
#endif

size_t
bytecount(const void *haystack, int n, size_t len)
{
    if (!USE_MM_BYTECOUNT || len < 16) {
        return naive_bytecount(haystack, n, len);
    }
    else {
        return mm_bytecount(haystack, n, len);
    }
}
