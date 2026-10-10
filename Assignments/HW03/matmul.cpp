#include "matmul.h"

#include <algorithm>

void mmul(const float* A, const float* B, float* C, const std::size_t n) {
    std::fill(C, C + n * n, 0.0f);

    // Each iteration owns one complete row of C, so no synchronization is
    // needed while accumulating that row.
    #pragma omp parallel for schedule(static)
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t k = 0; k < n; ++k) {
            const float a = A[i * n + k];
            for (std::size_t j = 0; j < n; ++j) {
                C[i * n + j] += a * B[k * n + j];
            }
        }
    }
}
