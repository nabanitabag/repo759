#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH --cpus-per-task=20
#SBATCH --mem=10G
#SBATCH -J hw03-task2
#SBATCH -o task2-%j.out
#SBATCH -e task2-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

g++ task2.cpp convolution.cpp -Wall -O3 -std=c++17 -o task2 -fopenmp

export OMP_DYNAMIC=FALSE
export OMP_PLACES=cores
export OMP_PROC_BIND=close

printf 'threads\ttime_ms\n' > task2_times.tsv
for threads in {1..20}; do
    result=$(./task2 1024 "$threads")
    elapsed_ms=$(printf '%s\n' "$result" | tail -n 1)
    printf '%d\t%s\n' "$threads" "$elapsed_ms" >> task2_times.tsv
done

python3 plot_task1.py task2_times.tsv task2.pdf \
    'HW03 Convolution (n = 1024, mask = 3x3)' 'convolve time (ms)'
