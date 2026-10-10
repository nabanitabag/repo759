#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH --cpus-per-task=20
#SBATCH --mem=10G
#SBATCH -J hw03-task1
#SBATCH -o task1-%j.out
#SBATCH -e task1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

g++ task1.cpp matmul.cpp -Wall -O3 -std=c++17 -o task1 -fopenmp

printf 'threads\ttime_ms\n' > task1_times.tsv
for threads in {1..20}; do
    result=$(./task1 1024 "$threads")
    elapsed_ms=$(printf '%s\n' "$result" | tail -n 1)
    printf '%d\t%s\n' "$threads" "$elapsed_ms" >> task1_times.tsv
done

python3 plot_task1.py task1_times.tsv task1.pdf
