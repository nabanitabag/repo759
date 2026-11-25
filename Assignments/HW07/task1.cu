#include "matmul.cuh"

#include <cstddef>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

static unsigned int parse_positive(const char *arg) {
    std::size_t parsed_characters = 0;
    const unsigned long long value = std::stoull(arg, &parsed_characters);
    if (arg[0] == '-' || parsed_characters != std::string(arg).size() || value == 0 ||
        value > std::numeric_limits<unsigned int>::max()) {
        throw std::out_of_range("value must be positive and representable");
    }
    return static_cast<unsigned int>(value);
}

template <typename T>
static void run(void (*matmul)(const T *, const T *, T *, unsigned int, unsigned int),
                unsigned int seed, unsigned int n, unsigned int block_dim) {
    const std::size_t size = static_cast<std::size_t>(n) * n;
    const std::size_t bytes = size * sizeof(T);

    // Same seed for every type, so int, float, and double multiply identical matrices.
    std::vector<T> A(size);
    std::vector<T> B(size);
    std::mt19937 generator(seed);
    std::uniform_int_distribution<int> distribution(-10, 10);
    for (std::size_t i = 0; i < size; ++i) {
        A[i] = static_cast<T>(distribution(generator));
        B[i] = static_cast<T>(distribution(generator));
    }

    T *dA;
    T *dB;
    T *dC;
    cudaMalloc((void **)&dA, bytes);
    cudaMalloc((void **)&dB, bytes);
    cudaMalloc((void **)&dC, bytes);
    cudaMemcpy(dA, A.data(), bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(dB, B.data(), bytes, cudaMemcpyHostToDevice);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    matmul(dA, dB, dC, n, block_dim);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    T first;
    T last;
    cudaMemcpy(&first, dC, sizeof(T), cudaMemcpyDeviceToHost);
    cudaMemcpy(&last, dC + size - 1, sizeof(T), cudaMemcpyDeviceToHost);

    std::cout << first << '\n';
    std::cout << last << '\n';
    std::cout << elapsed_ms << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(dA);
    cudaFree(dB);
    cudaFree(dC);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <positive block_dim>\n";
        return 1;
    }

    unsigned int n;
    unsigned int block_dim;
    try {
        n = parse_positive(argv[1]);
        block_dim = parse_positive(argv[2]);
    } catch (const std::exception &) {
        std::cerr << "n and block_dim must be positive integers.\n";
        return 1;
    }
    if (block_dim > 32) {
        std::cerr << "block_dim must be at most 32 (block_dim * block_dim threads per block).\n";
        return 1;
    }

    const unsigned int seed = std::random_device{}();
    run<int>(matmul_1, seed, n, block_dim);
    run<float>(matmul_2, seed, n, block_dim);
    run<double>(matmul_3, seed, n, block_dim);
    return 0;
}
