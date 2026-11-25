#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:30:00
#SBATCH --ntasks=1 --gpus-per-task=1 -c 1
#SBATCH --mem=12G
#SBATCH -J hw07-task2
#SBATCH -o task2-%j.out
#SBATCH -e task2-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module load nvidia/cuda

nvcc task2.cu reduce.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task2

# Untimed warm-up so one-time GPU startup cost doesn't land on the first data point.
./task2 1024 1024 > /dev/null

printf 'threads_per_block\tn\ttime_ms\n' > task2_times.tsv
for threads_per_block in 1024 256; do
    for exponent in {10..30}; do
        N=$((2 ** exponent))
        elapsed_ms=$(./task2 "$N" "$threads_per_block" | tail -n 1)
        printf '%d\t%d\t%s\n' "$threads_per_block" "$N" "$elapsed_ms" >> task2_times.tsv
        printf '%d threads/block, N = %d: %s ms\n' "$threads_per_block" "$N" "$elapsed_ms"
    done
done

python3 plot_scaling.py task2_times.tsv task2.pdf "HW07 task2: reduction time vs. N"
