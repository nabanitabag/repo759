#include "stencil.cuh"

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
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <positive R> <positive threads_per_block>\n";
        return 1;
    }

    unsigned int n;
    unsigned int R;
    unsigned int threads_per_block;
    try {
        n = parse_positive(argv[1]);
        R = parse_positive(argv[2]);
        threads_per_block = parse_positive(argv[3]);
    } catch (const std::exception &) {
        std::cerr << "n, R, and threads_per_block must be positive integers.\n";
        return 1;
    }
    if (threads_per_block < 2ULL * R + 1) {
        std::cerr << "threads_per_block must be at least 2 * R + 1.\n";
        return 1;
    }

    const std::size_t mask_size = 2 * static_cast<std::size_t>(R) + 1;
    std::vector<float> image(n);
    std::vector<float> mask(mask_size);
    std::vector<float> output(n);

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution(
        -1.0f, std::nextafter(1.0f, std::numeric_limits<float>::max()));
    for (auto &value : image) {
        value = distribution(generator);
    }
    for (auto &value : mask) {
        value = distribution(generator);
    }

    float *d_image;
    float *d_mask;
    float *d_output;
    cudaMalloc((void **)&d_image, n * sizeof(float));
    cudaMalloc((void **)&d_mask, mask_size * sizeof(float));
    cudaMalloc((void **)&d_output, n * sizeof(float));
    cudaMemcpy(d_image, image.data(), n * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_mask, mask.data(), mask_size * sizeof(float), cudaMemcpyHostToDevice);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    stencil(d_image, d_mask, d_output, n, R, threads_per_block);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_ms = 0.0f;
    cudaEventElapsedTime(&elapsed_ms, start, stop);

    cudaMemcpy(output.data(), d_output, n * sizeof(float), cudaMemcpyDeviceToHost);

    std::cout << output[n - 1] << '\n';
    std::cout << elapsed_ms << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_image);
    cudaFree(d_mask);
    cudaFree(d_output);
    return 0;
}
