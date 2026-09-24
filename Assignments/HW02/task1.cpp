#include "scan.h"

#include <chrono>
#include <cstddef>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>

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
            parsed_n > std::numeric_limits<std::size_t>::max()) {
            throw std::out_of_range("n must be positive and representable");
        }
        n = static_cast<std::size_t>(parsed_n);
    } catch (const std::exception &) {
        std::cerr << "n must be a positive integer.\n";
        return 1;
    }

    float *arr = new float[n];
    float *output = new float[n];

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution(-1.0f, 1.0f);

    for (std::size_t i = 0; i < n; ++i) {
        arr[i] = distribution(generator);
    }

    const auto start = std::chrono::high_resolution_clock::now();
    scan(arr, output, n);
    const auto end = std::chrono::high_resolution_clock::now();

    const std::chrono::duration<double, std::milli> duration = end - start;
    std::cout << duration.count() << '\n';
    
    std::cout << output[0] << '\n';
    std::cout << output[n - 1] << '\n';

    delete[] arr;
    delete[] output;
    return 0;
}
