#include "msort.h"

#include <charconv>
#include <chrono>
#include <iostream>
#include <random>
#include <string>
#include <system_error>
#include <vector>

namespace {

bool parse_size(const char* argument, std::size_t& value) {
    const std::string text(argument);
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    return result.ec == std::errc{} && result.ptr == text.data() + text.size();
}

}  // namespace

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <positive n> <threads 1-20> <threshold>\n";
        return 1;
    }

    std::size_t n = 0;
    std::size_t thread_count = 0;
    std::size_t threshold = 0;
    if (!parse_size(argv[1], n) || n == 0 ||
        !parse_size(argv[2], thread_count) || thread_count < 1 || thread_count > 20 ||
        !parse_size(argv[3], threshold)) {
        std::cerr << "n must be positive, t must be between 1 and 20, "
                     "and ts must be a nonnegative integer.\n";
        return 1;
    }

    std::vector<int> arr(n);
    std::mt19937 generator(42);
    std::uniform_int_distribution<int> distribution(-1000, 1000);
    for (int& value : arr) {
        value = distribution(generator);
    }

    omp_set_num_threads(static_cast<int>(thread_count));
    const auto start = std::chrono::steady_clock::now();
    msort(arr.data(), n, threshold);
    const auto end = std::chrono::steady_clock::now();

    const std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << arr.front() << '\n';
    std::cout << arr.back() << '\n';
    std::cout << elapsed.count() << '\n';
    return 0;
}
