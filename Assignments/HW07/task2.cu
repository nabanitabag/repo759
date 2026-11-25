#include "reduce.cuh"

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
        std::cerr << "Usage: " << argv[0] << " <positive N> <positive threads_per_block>\n";
        return 1;
    }

    unsigned int N;
    unsigned int threads_per_block;
    try {
        N = parse_positive(argv[1]);
        threads_per_block = parse_positive(argv[2]);
    } catch (const std::exception &) {
        std::cerr << "N and threads_per_block must be positive integers.\n";
        return 1;
    }

    std::vector<float> values(N);
    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution(
        -1.0f, std::nextafter(1.0f, std::numeric_limits<float>::max()));
    for (auto &value : values) {
        value = distribution(generator);
    }

    const unsigned int first_pass_blocks = (N + 2 * threads_per_block - 1) / (2 * threads_per_block);
    float *d_input;
    float *d_output;
    cudaMalloc((void **)&d_input, N * sizeof(float));
    cudaMalloc((void **)&d_output, first_pass_blocks * sizeof(float));
    cudaMemcpy(d_input, values.data(), N * sizeof(float), cudaMemcpyHostToDevice);

    // Untimed empty launch (n = 0 reads no input) so the one-time kernel load isn't measured.
    reduce_kernel<<<1, threads_per_block, threads_per_block * sizeof(float)>>>(d_input, d_output, 0);
    cudaDeviceSynchronize();

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    reduce(&d_input, &d_output, N, threads_per_block);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    float sum = 0.0f;
    cudaMemcpy(&sum, d_input, sizeof(float), cudaMemcpyDeviceToHost);

    std::cout << sum << '\n';
    std::cout << elapsed_ms << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_input);
    cudaFree(d_output);
    return 0;
}
