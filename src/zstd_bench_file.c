#include <assert.h>
#include <bits/time.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <zstd.h>
#include <time.h>

typedef float f32;
typedef double f64;
typedef int32_t i32;
typedef int64_t i64;
typedef uint64_t u64;
typedef size_t usize;

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

static i64 flen(FILE *file) {
    assert(ftell(file) == 0);

    i64 seeked = fseek(file, 0, SEEK_END);
    CHECK(seeked == 0, "Unable to seek file");

    i64 end = ftell(file);
    rewind(file);

    return end;
}

static char *read_file(const char fname[], usize *size) {
    FILE *file = fopen(fname, "r");
    CHECK(file != NULL, "Unable to open file");

    *size = flen(file);

    char *data = malloc((*size + 1) * sizeof(char));

    usize total_read = fread(data, sizeof(char), *size, file);
    CHECK(total_read == *size, "Unable to read file");

    fclose(file);

    return data;
}

static f64 get_time_s() {
    struct timespec now;

    clock_gettime(CLOCK_REALTIME, &now);

    return now.tv_sec + now.tv_nsec * 1e-9;
}

static void decompress(const char *fname) {
    usize comp_size;
    const char *comp = read_file(fname, &comp_size);

    const u64 raw_size = ZSTD_getFrameContentSize(comp, comp_size);

    CHECK(raw_size != ZSTD_CONTENTSIZE_ERROR, "%s: not compressed by zstd!", fname);
    CHECK(raw_size != ZSTD_CONTENTSIZE_UNKNOWN, "%s: original size unknown!", fname);

    char *decomp = malloc((raw_size + 1) * sizeof(char));

    f64 time_start = get_time_s();

    const usize decomp_size = ZSTD_decompress(decomp, raw_size, comp, comp_size);

    CHECK_ZSTD(decomp_size);

    printf("%15s : %6lu -> %7lu \n", fname, comp_size, raw_size);
    printf("\t done in %.2fs", get_time_s() - time_start);

    free(decomp);
    free((void *)comp);
}

int main(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("Usage: main.c filename\n");
        exit(2);
    }
    const char *fname = argv[1];

    decompress(fname);
}
