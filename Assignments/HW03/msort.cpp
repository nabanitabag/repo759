#include "msort.h"

#include <algorithm>
#include <vector>

namespace {

void merge_sort(int* arr, int* scratch, std::size_t n,
                std::size_t threshold) {
    if (n < 2) {
        return;
    }
    if (n < threshold) {
        std::sort(arr, arr + n);
        return;
    }

    const std::size_t midpoint = n / 2;

    // Each task owns a disjoint portion of both arrays.
#pragma omp task default(none) firstprivate(arr, scratch, midpoint, threshold)
    merge_sort(arr, scratch, midpoint, threshold);

#pragma omp task default(none) firstprivate(arr, scratch, n, midpoint, threshold)
    merge_sort(arr + midpoint, scratch + midpoint, n - midpoint, threshold);

#pragma omp taskwait
    std::merge(arr, arr + midpoint, arr + midpoint, arr + n, scratch);
    std::copy(scratch, scratch + n, arr);
}

}  // namespace

void msort(int* arr, const std::size_t n, const std::size_t threshold) {
    if (n < 2) {
        return;
    }
    if (n < threshold) {
        std::sort(arr, arr + n);
        return;
    }

    // Allocate once and reuse the buffer throughout the recursion.
    std::vector<int> scratch(n);
    int* buffer = scratch.data();
#pragma omp parallel default(none) shared(arr, buffer, n, threshold)
    {
#pragma omp single
        merge_sort(arr, buffer, n, threshold);
    }
}
