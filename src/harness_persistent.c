#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>

#define MAX_IMAGE_DIM 4096

#ifndef __AFL_LOOP
static int afl_loop_fallback(unsigned int max_iterations) {
    static int once = 1;
    (void)max_iterations;
    if (!once) {
        return 0;
    }
    once = 0;
    return 1;
}
#define __AFL_LOOP(x) afl_loop_fallback(x)
#endif

static int fuzz_one(const char *filename) {
    FILE *fp = NULL;
    png_structp png = NULL;
    png_infop info = NULL;
    png_bytep *rows = NULL;
    png_uint_32 height = 0;
    png_uint_32 allocated_rows = 0;

    fp = fopen(filename, "rb");
    if (!fp) {
        return 0;
    }

    png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) {
        fclose(fp);
        return 0;
    }

    info = png_create_info_struct(png);
    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        fclose(fp);
        return 0;
    }

    /*
     * Important in persistent mode:
     * if libpng longjmps because of a malformed input,
     * we must clean everything from this iteration.
     */
    if (setjmp(png_jmpbuf(png))) {
        if (rows) {
            for (png_uint_32 i = 0; i < allocated_rows; i++) {
                free(rows[i]);
            }
            free(rows);
        }

        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    png_init_io(png, fp);

    png_read_info(png, info);

    png_uint_32 width = png_get_image_width(png, info);
    height = png_get_image_height(png, info);

    if (width == 0 || height == 0 ||
        width > MAX_IMAGE_DIM || height > MAX_IMAGE_DIM) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    png_set_expand(png);
    png_set_strip_16(png);
    png_set_gray_to_rgb(png);

    png_read_update_info(png, info);

    png_uint_32 rowbytes = png_get_rowbytes(png, info);

    rows = (png_bytep *)malloc(height * sizeof(png_bytep));
    if (!rows) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    for (png_uint_32 i = 0; i < height; i++) {
        rows[i] = (png_bytep)malloc(rowbytes);
        if (!rows[i]) {
            for (png_uint_32 j = 0; j < i; j++) {
                free(rows[j]);
            }
            free(rows);
            png_destroy_read_struct(&png, &info, NULL);
            fclose(fp);
            return 0;
        }

        allocated_rows++;
    }

    png_read_image(png, rows);

    /*
     * This is useful for your lab because it reaches post-IDAT chunks.
     * As you wrote, this can trigger the vulnerable png_set_text_2() path.
     */
    png_read_end(png, NULL);

    for (png_uint_32 i = 0; i < allocated_rows; i++) {
        free(rows[i]);
    }

    free(rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        return 1;
    }

    while (__AFL_LOOP(1000)) {
        fuzz_one(argv[1]);
    }

    return 0;
}
