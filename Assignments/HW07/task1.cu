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
                const std::vector<int> &a_values, const std::vector<int> &b_values, unsigned int n,
                unsigned int block_dim) {
    const std::size_t size = static_cast<std::size_t>(n) * n;
    const std::size_t bytes = size * sizeof(T);
    T *A;
    T *B;
    T *C;
    cudaMallocManaged((void **)&A, bytes);
    cudaMallocManaged((void **)&B, bytes);
    cudaMallocManaged((void **)&C, bytes);
    for (std::size_t i = 0; i < size; ++i) {
        A[i] = static_cast<T>(a_values[i]);
        B[i] = static_cast<T>(b_values[i]);
    }

    // Move the data to the GPU first so page migration isn't counted as matmul time.
    int device;
    cudaGetDevice(&device);
    cudaMemPrefetchAsync(A, bytes, device);
    cudaMemPrefetchAsync(B, bytes, device);
    cudaMemPrefetchAsync(C, bytes, device);
    cudaDeviceSynchronize();

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    matmul(A, B, C, n, block_dim);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    std::cout << C[0] << '\n';
    std::cout << C[size - 1] << '\n';
    std::cout << elapsed_ms << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(A);
    cudaFree(B);
    cudaFree(C);
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

    const std::size_t size = static_cast<std::size_t>(n) * n;
    std::vector<int> a_values(size);
    std::vector<int> b_values(size);
    std::mt19937 generator(std::random_device{}());
    std::uniform_int_distribution<int> distribution(-10, 10);
    for (std::size_t i = 0; i < size; ++i) {
        a_values[i] = distribution(generator);
        b_values[i] = distribution(generator);
    }

    run<int>(matmul_1, a_values, b_values, n, block_dim);
    run<float>(matmul_2, a_values, b_values, n, block_dim);
    run<double>(matmul_3, a_values, b_values, n, block_dim);
    return 0;
}
