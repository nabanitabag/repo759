#include "matmul.cuh"

#include <cmath>
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

int main(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <positive threads_per_block>\n";
        return 1;
    }

    std::size_t n;
    unsigned int threads_per_block;
    try {
        n = parse_positive(argv[1]);
        threads_per_block = parse_positive(argv[2]);
    } catch (const std::exception &) {
        std::cerr << "n and threads_per_block must be positive integers.\n";
        return 1;
    }

    const std::size_t size = n * n;
    std::vector<float> A(size);
    std::vector<float> B(size);
    std::vector<float> C(size);

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution(
        -1.0f, std::nextafter(1.0f, std::numeric_limits<float>::max()));
    for (std::size_t i = 0; i < size; ++i) {
        A[i] = distribution(generator);
        B[i] = distribution(generator);
    }

    float *dA;
    float *dB;
    float *dC;
    cudaMalloc((void **)&dA, size * sizeof(float));
    cudaMalloc((void **)&dB, size * sizeof(float));
    cudaMalloc((void **)&dC, size * sizeof(float));
    cudaMemcpy(dA, A.data(), size * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dB, B.data(), size * sizeof(float), cudaMemcpyHostToDevice);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    matmul(dA, dB, dC, n, threads_per_block);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    cudaMemcpy(C.data(), dC, size * sizeof(float), cudaMemcpyDeviceToHost);

    std::cout << C[size - 1] << '\n';
    std::cout << elapsed_ms << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(dA);
    cudaFree(dB);
    cudaFree(dC);
    return 0;
}
