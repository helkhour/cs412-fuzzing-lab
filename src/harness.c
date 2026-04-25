#include <png.h>   
#include <stdio.h>    // -> fopen, fclose
#include <stdlib.h>   // -> malloc, free
#include <setjmp.h>   // -> setjmp/longjmp

int main(int argc, char **argv) {

    // If no file is provided, exit.
    if (argc < 2) return 0;

    // Open file given by AFL++ 
    FILE *fp = fopen(argv[1], "rb");    // argv[1] is the path to the mutated PNG file.
    // If the file couldn't be opened, exit.
    if (!fp) return 0;

    // Libpng decoder object which holds all of libpng's internal state.
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL NULL, NULL);
    // If creation failed, cloe the file and exit.
    if (!png) {
        fclose(fp);
        return 0;
    }

    png_infop info = png_create_info_struct(png);

    // Libpng info object which stores image metadata after reafing IHDR.
    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        fclose(fp);
        return 0;
    }

    // Error handler only runs if libpng calls longjmp.
    if (setjmp(png_jmpbuf(png))) {
        // Clean up and then exit
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    // Read file.
    png_init_io(png, fp);

    // Read all chunks up to but not including IDAT.
    // After this, the info object contains: image width + image height + color type + bit depth + other metadata chunks
    png_read_info(png, info);

    // TRANSFORMATIONS each one opens a new code path for AFL++ to explore.

    // Converts palette images to full rgb.
    png_set_expand(png);

    // Converts 16-bit depth images to 8-bit.
    png_set_strip_16(png);

    // Converts grayscale images to RGB
    png_set_gray_to_rgb(png);

    // Recalculates the info object after applying transformations.
    // Libpng needs to update width/height/rowbytes based on the transformations.
    png_read_update_info(png, info);

    // Get the image dimensions and row size.
    png_uint_32 width = png_get_image_width(png, info);
    png_uint_32 height = png_get_image_height(png, info);
    png_uint_32 rowbytes = png_get_rowbytes(png, info);


    // FUZZING GUARD (not a part of the decoding sequence provided in the document): reject "too" big dimensions from malformed IHDR chunks to prevent the fuzzer from hanging.
    if (width == 0 || height == 0 || width > 1000 || height > 1000) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    // Allocate array of row pointers (one pointer per row).
    png_bytep *rows = malloc(height * sizeof(png_bytep));
    if (!rows) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    // Allocate memory for each individual row.
    for (png_uint_32 i = 0; i < height; i++) {
        rows[i] = malloc(rowbytes);
        if (!rows[i]) {
            // If any row allocation fails, free everything allocated so far
            for (png_uint_32 j = 0; j < i; j++) free(rows[j]);
            free(rows);
            png_destroy_read_struct(&png, &info, NULL);
            fclose(fp);
            return 0;
        }
    }

    // Read the actual pixel data.
    png_read_image(png, rows);

    // Read any remaining chunks after IDAT.
    png_read_end(png, NULL);


    // CLEANUP: free allocated memory
    for (png_uint_32 i = 0; i < height; i++) free(rows[i]);
    free(rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    return 0;
}