#include <png.h>   
#include <stdio.h>    // -> fopen, fclose
#include <stdlib.h>   // -> malloc, free
#include <setjmp.h>   // -> setjmp/longjmp

#define MAX_IMAGE_DIM 4096

int main(int argc, char **argv) {
    // 1. OPEN FILE.

    // If no file is provided, exit.
    if (argc < 2) {
        printf("No file provided");
        return 1;
    }

    // Open file given by AFL++. 
    FILE *fp = fopen(argv[1], "rb");    // argv[1] is the path to the mutated PNG file.
    // If the file couldn't be opened, exit and do not log this as a crash.
    if (!fp) return 0;



    // 2. CREATE LIBPNG OBJECTS.

    // Libpng decoder object which holds all of libpng's internal state.
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    // If creation failed, close the file and exit and do not log this as a crash.
    if (!png) {
        fclose(fp);
        return 0;
    }

    // Libpng info object which stores image metadata after reafing IHDR.
    png_infop info = png_create_info_struct(png);

    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        fclose(fp);
        return 0;
    }



    // 3. INSTALL ERROR HANDLER.

    // Error handler only runs if libpng calls longjmp.
    if (setjmp(png_jmpbuf(png))) {
        // Clean up and then exit
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0; 
    }



    // 4. TELL LIBPNG WHERE THE BYTES COME FROM.

    // Read file.
    png_init_io(png, fp);



    // 5. READ AND PARSE ALL CHUNKS UP TO (not including) IDAT.

    // After this, the info object contains: image width + image height + color type + bit depth + other metadata chunks
    png_read_info(png, info);



    // 6. FUZZING GUARD: reject "too" big dimensions from malformed IHDR chunks to prevent the fuzzer from hanging.

    // Get the image dimensions.
    png_uint_32 width = png_get_image_width(png, info);
    png_uint_32 height = png_get_image_height(png, info);

    if (width == 0 || height == 0 || width > MAX_IMAGE_DIM || height > MAX_IMAGE_DIM) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }



    // 7. TRANSFORMATIONS: each one opens a new decoding code path for AFL++ to explore.

    // Converts palette images to full rgb.
    png_set_expand(png);

    // Converts 16-bit depth images to 8-bit.
    png_set_strip_16(png);

    // Converts grayscale images to RGB.
    png_set_gray_to_rgb(png);

    //png_set_interlace_handling(png);

    // Recalculates the info object after applying transformations.
    // Libpng needs to update width/height/rowbytes based on the transformations.
    png_read_update_info(png, info);



    // 8. ALLOCATE ROW BUFFERS

    // Allocate array of row pointers (one pointer per row).
    png_bytep *rows = (png_bytep *) malloc(height * sizeof(png_bytep));
    if (!rows) {
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return 0;
    }

    // Get row size.
    png_uint_32 rowbytes = png_get_rowbytes(png, info);

    // Allocate memory for each individual row.
    for (png_uint_32 i = 0; i < height; i++) {
        rows[i] = (png_bytep) malloc(rowbytes);
        if (!rows[i]) {
            // If any row allocation fails, free everything allocated so far
            for (png_uint_32 j = 0; j < i; j++) free(rows[j]);
            free(rows);
            png_destroy_read_struct(&png, &info, NULL);
            fclose(fp);
            return 0;
        }
    }



    // 9. DECODE THE PIXEL DATA. 

    // Read the actual pixel data.
    png_read_image(png, rows);



    // 10. PROCESS POST-IDAT CHUNKS

    // Read any remaining chunks after IDAT.
    png_read_end(png, NULL); // !! This is the call that triggers png_set_text_2() CVE-2016-10087

    

    // 11. CLEANUP: free allocated memory
    for (png_uint_32 i = 0; i < height; i++) free(rows[i]);
    free(rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    return 0;
}