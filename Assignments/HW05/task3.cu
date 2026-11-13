#include "vscale.cuh"

#include <cstddef>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>

#ifndef THREADS_PER_BLOCK
#define THREADS_PER_BLOCK 512
#endif

int main(int argc, char *argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <positive n>\n";
        return 1;
    }

    std::size_t n;
    try {
        std::size_t parsed_characters = 0;
        const unsigned long long parsed_n = std::stoull(argv[1], &parsed_characters);
        if (argv[1][0] == '-' || parsed_characters != std::string(argv[1]).size() ||
            parsed_n == 0 ||
            parsed_n > std::numeric_limits<unsigned int>::max()) {
            throw std::out_of_range("n must be positive and representable");
        }
        n = static_cast<std::size_t>(parsed_n);
    } catch (const std::exception &) {
        std::cerr << "n must be a positive integer.\n";
        return 1;
    }

    float *a = new float[n];
    float *b = new float[n];

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution_a(-10.0f, 10.0f);
    std::uniform_real_distribution<float> distribution_b(0.0f, 1.0f);

    for (std::size_t i = 0; i < n; ++i) {
        a[i] = distribution_a(generator);
        b[i] = distribution_b(generator);
    }

    float *dA;
    float *dB;
    cudaMalloc((void **)&dA, n * sizeof(float));
    cudaMalloc((void **)&dB, n * sizeof(float));
    cudaMemcpy(dA, a, n * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dB, b, n * sizeof(float), cudaMemcpyHostToDevice);

    const unsigned int threads_per_block = THREADS_PER_BLOCK;
    const unsigned int blocks =
        (static_cast<unsigned int>(n) + threads_per_block - 1) / threads_per_block;

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    vscale<<<blocks, threads_per_block>>>(dA, dB, static_cast<unsigned int>(n));
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    cudaMemcpy(b, dB, n * sizeof(float), cudaMemcpyDeviceToHost);

    std::cout << elapsed_ms << '\n';
    std::cout << b[0] << '\n';
    std::cout << b[n - 1] << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(dA);
    cudaFree(dB);
    delete[] a;
    delete[] b;
    return 0;
}
