#include "convolution.h"

void convolve(const float *image, float *output, std::size_t n,
              const float *mask, std::size_t m) {
    const std::size_t radius = m / 2;

    for (std::size_t x = 0; x < n; ++x) {
        for (std::size_t y = 0; y < n; ++y) {
            float sum = 0.0f;

            for (std::size_t i = 0; i < m; ++i) {
                const bool row_before_image = i < radius;
                const std::size_t row_offset = row_before_image ? radius - i : i - radius;
                const bool row_in_bounds = row_before_image ? x >= row_offset
                                                            : row_offset < n - x;
                const std::size_t image_x = row_before_image ? x - row_offset
                                                              : x + row_offset;

                for (std::size_t j = 0; j < m; ++j) {
                    const bool column_before_image = j < radius;
                    const std::size_t column_offset =
                        column_before_image ? radius - j : j - radius;
                    
                    const bool column_in_bounds = column_before_image
                                                      ? y >= column_offset
                                                      : column_offset < n - y;
                    const std::size_t image_y = column_before_image
                                                    ? y - column_offset
                                                    : y + column_offset;

                    float image_value = 0.0f;
                    if (row_in_bounds && column_in_bounds) {
                        image_value = image[image_x * n + image_y];
                    } else if (row_in_bounds || column_in_bounds) {
                        image_value = 1.0f;
                    }

                    sum += mask[i * m + j] * image_value;
                }
            }

            output[x * n + y] = sum;
        }
    }
}
