#include <assert.h>
#include <bits/time.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <zstd.h>
#include <time.h>
#include "silezia_comp.h"

typedef float f32;
typedef double f64;
typedef int32_t i32;
typedef int64_t i64;
typedef uint8_t u8;
typedef uint64_t u64;
typedef size_t usize;

usize comp_size = 73292309;

const char *comp = (const char *)src_silesia_tar_zst;

#define CHECK(cond, args...)                                                                                 \
do {                                                                                                     \
    if (!(cond)) {                                                                                       \
        fprintf(stderr, args);                                                                           \
        fprintf(stderr, "\n");                                                                           \
        exit(1);                                                                                         \
    }                                                                                                    \
} while (0)

#define CHECK_ZSTD(res)                                                                                      \
do {                                                                                                     \
    CHECK(!(ZSTD_isError(res)), "ZSTD ERROR: %s", ZSTD_getErrorName(res));                               \
} while (0)

static f64 get_time_s() {
    struct timespec now;

    clock_gettime(CLOCK_REALTIME, &now);

    return now.tv_sec + now.tv_nsec * 1e-9;
}

static void decompress() {
    const u64 raw_size = ZSTD_getFrameContentSize(comp, comp_size);

    char *decomp = malloc((raw_size + 1) * sizeof(char));

    f64 time_start = get_time_s();

    const usize decomp_size = ZSTD_decompress(decomp, raw_size, comp, comp_size);

    CHECK_ZSTD(decomp_size);

    printf("%15s : %luB -> %luB \n", "silesia.tar.zst", comp_size, raw_size);
    printf("\t done in %.2fs\n", get_time_s() - time_start);

    free(decomp);
}

int main(int argc, const char *argv[]) {
    decompress();
}

