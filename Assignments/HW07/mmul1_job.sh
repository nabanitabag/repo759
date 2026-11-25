#!/usr/bin/env bash

# Part (f): time HW02's serial mmul1 at n = 2^14 on the CPU, cut off at 10 minutes.

#SBATCH -p instruction
#SBATCH -t 0-00:20:00
#SBATCH -c 1
#SBATCH --mem=8G
#SBATCH -J hw07-mmul1
#SBATCH -o mmul1-%j.out
#SBATCH -e mmul1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cat > "$build_dir/mmul1_driver.cpp" <<'CPP'
#include "matmul.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <random>
#include <vector>

int main(int argc, char *argv[]) {
    const unsigned int n = static_cast<unsigned int>(std::strtoul(argv[1], nullptr, 10));
    std::vector<double> A(static_cast<std::size_t>(n) * n);
    std::vector<double> B(A.size());
    std::vector<double> C(A.size());
    std::mt19937 generator(759);
    std::uniform_real_distribution<double> distribution(-1.0, 1.0);
    for (std::size_t i = 0; i < A.size(); ++i) {
        A[i] = distribution(generator);
        B[i] = distribution(generator);
    }

    const auto start = std::chrono::high_resolution_clock::now();
    mmul1(A.data(), B.data(), C.data(), n);
    const auto end = std::chrono::high_resolution_clock::now();
    const std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << elapsed.count() << '\n';
    return 0;
}
CPP

g++ -I../HW02 ../HW02/matmul.cpp "$build_dir/mmul1_driver.cpp" -Wall -O3 -std=c++17 -o "$build_dir/mmul1"

for n in 1024 2048; do
    printf 'mmul1, n = %d: %s ms\n' "$n" "$("$build_dir/mmul1" "$n")"
done

if elapsed_ms=$(timeout 600 "$build_dir/mmul1" 16384); then
    printf 'mmul1, n = 16384: %s ms\n' "$elapsed_ms"
else
    printf 'mmul1, n = 16384: did not finish within 10 minutes\n'
fi
