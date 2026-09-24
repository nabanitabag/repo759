#include "matmul.h"

#include <chrono>
#include <iostream>
#include <random>
#include <vector>

int main() {
    constexpr unsigned int n = 1000;
    const std::size_t matrix_size = static_cast<std::size_t>(n) * n;

    std::vector<double> A(matrix_size);
    std::vector<double> B(matrix_size);
    std::vector<double> C(matrix_size);

    std::mt19937 generator(42);
    std::uniform_real_distribution<double> distribution(-1.0, 1.0);
    for (std::size_t i = 0; i < matrix_size; ++i) {
        A[i] = distribution(generator);
        B[i] = distribution(generator);
    }

    std::cout << n << '\n';

    auto time_and_print = [&C](auto multiply) {
        const auto start = std::chrono::high_resolution_clock::now();
        multiply();
        const auto end = std::chrono::high_resolution_clock::now();

        const std::chrono::duration<double, std::milli> elapsed = end - start;
        std::cout << elapsed.count() << '\n';
        std::cout << C[matrix_size - 1] << '\n';
    };

    time_and_print([&A, &B, &C] { mmul1(A.data(), B.data(), C.data(), n); });
    time_and_print([&A, &B, &C] { mmul2(A.data(), B.data(), C.data(), n); });
    time_and_print([&A, &B, &C] { mmul3(A.data(), B.data(), C.data(), n); });
    time_and_print([&A, &B, &C] { mmul4(A, B, C.data(), n); });

    return 0;
}
