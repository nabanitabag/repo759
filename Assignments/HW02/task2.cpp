#include "convolution.h"

#include <chrono>
#include <cstddef>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>

namespace {

bool parse_positive_size(const char *argument, std::size_t &value) {
    try {
        const std::string text(argument);
        std::size_t parsed_characters = 0;
        const unsigned long long parsed_value =
            std::stoull(text, &parsed_characters);

        if (text.empty() || text[0] == '-' || parsed_characters != text.size() ||
            parsed_value == 0 ||
            parsed_value > std::numeric_limits<std::size_t>::max()) {
            return false;
        }

        value = static_cast<std::size_t>(parsed_value);
        return true;
    } catch (const std::exception &) {
        return false;
    }
}

}  // namespace

int main(int argc, char *argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <positive odd m>\n";
        return 1;
    }

    std::size_t n;
    std::size_t m;
    if (!parse_positive_size(argv[1], n) || !parse_positive_size(argv[2], m) ||
        m % 2 == 0) {
        std::cerr << "n must be positive, and m must be a positive odd integer.\n";
        return 1;
    }

    if (n > std::numeric_limits<std::size_t>::max() / n ||
        m > std::numeric_limits<std::size_t>::max() / m) {
        std::cerr << "Matrix dimensions are too large.\n";
        return 1;
    }

    const std::size_t image_size = n * n;
    const std::size_t mask_size = m * m;
    float *image = new float[image_size];
    float *mask = new float[mask_size];
    float *output = new float[image_size];

    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> image_distribution(-10.0f, 10.0f);
    std::uniform_real_distribution<float> mask_distribution(-1.0f, 1.0f);

    for (std::size_t i = 0; i < image_size; ++i) {
        image[i] = image_distribution(generator);
    }
    for (std::size_t i = 0; i < mask_size; ++i) {
        mask[i] = mask_distribution(generator);
    }

    const auto start = std::chrono::high_resolution_clock::now();
    convolve(image, output, n, mask, m);
    const auto end = std::chrono::high_resolution_clock::now();

    const std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << elapsed.count() << '\n';
    std::cout << output[0] << '\n';
    std::cout << output[image_size - 1] << '\n';

    delete[] image;
    delete[] mask;
    delete[] output;
    return 0;
}
