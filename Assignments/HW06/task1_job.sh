#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:30:00
#SBATCH --ntasks=1 --gpus-per-task=1 -c 1
#SBATCH --mem=8G
#SBATCH -J hw06-task1
#SBATCH -o task1-%j.out
#SBATCH -e task1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module load nvidia/cuda

nvcc task1.cu matmul.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task1

# Untimed warm-up so one-time GPU startup cost doesn't land on the first data point.
./task1 32 1024 > /dev/null

printf 'threads_per_block\tn\ttime_ms\n' > task1_times.tsv
for threads_per_block in 1024 256; do
    for exponent in {5..14}; do
        n=$((2 ** exponent))
        elapsed_ms=$(./task1 "$n" "$threads_per_block" | tail -n 1)
        printf '%d\t%d\t%s\n' "$threads_per_block" "$n" "$elapsed_ms" >> task1_times.tsv
        printf '%d threads/block, n = %d: %s ms\n' "$threads_per_block" "$n" "$elapsed_ms"
    done
done

python3 plot_scaling.py task1_times.tsv task1.pdf "HW06 task1: matmul time vs. n"
