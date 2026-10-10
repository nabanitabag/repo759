#include "convolution.h"

#include <chrono>
#include <cstddef>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <threads 1-20>\n";
        return 1;
    }

    std::size_t n;
    int thread_count;
    try {
        std::size_t parsed_characters = 0;
        const unsigned long long parsed_n = std::stoull(argv[1], &parsed_characters);
        if (argv[1][0] == '-' || parsed_characters != std::string(argv[1]).size() ||
            parsed_n == 0 || parsed_n > std::numeric_limits<std::size_t>::max()) {
            throw std::out_of_range("n must be positive and representable");
        }
        n = static_cast<std::size_t>(parsed_n);

        parsed_characters = 0;
        const long parsed_threads = std::stol(argv[2], &parsed_characters);
        if (parsed_characters != std::string(argv[2]).size() ||
            parsed_threads < 1 || parsed_threads > 20) {
            throw std::out_of_range("thread count must be between 1 and 20");
        }
        thread_count = static_cast<int>(parsed_threads);
    } catch (const std::exception&) {
        std::cerr << "n must be positive and t must be an integer from 1 to 20.\n";
        return 1;
    }

    if (n > std::numeric_limits<std::size_t>::max() / n) {
        std::cerr << "n is too large.\n";
        return 1;
    }

    constexpr std::size_t mask_width = 3;
    const std::size_t image_size = n * n;
    std::vector<float> image(image_size);
    std::vector<float> mask(mask_width * mask_width);
    std::vector<float> output(image_size);

    std::mt19937 generator(42);
    std::uniform_real_distribution<float> image_distribution(-10.0f, 10.0f);
    std::uniform_real_distribution<float> mask_distribution(-1.0f, 1.0f);
    for (float& value : image) {
        value = image_distribution(generator);
    }
    for (float& value : mask) {
        value = mask_distribution(generator);
    }

    omp_set_num_threads(thread_count);
    const auto start = std::chrono::high_resolution_clock::now();
    convolve(image.data(), output.data(), n, mask.data(), mask_width);
    const auto end = std::chrono::high_resolution_clock::now();

    const std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << output[0] << '\n';
    std::cout << output[image_size - 1] << '\n';
    std::cout << elapsed.count() << '\n';
    return 0;
}
