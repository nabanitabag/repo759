#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:45:00
#SBATCH --ntasks=1 --gpus-per-task=1 -c 1
#SBATCH --mem=8G
#SBATCH -J hw05-task3
#SBATCH -o task3-%j.out
#SBATCH -e task3-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module load nvidia/cuda

nvcc task3.cu vscale.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task3
nvcc task3.cu vscale.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -DTHREADS_PER_BLOCK=16 -o task3_16

printf 'threads_per_block\tn\ttime_ms\n' > task3_times.tsv
for exponent in {10..29}; do
    n=$((2 ** exponent))

    elapsed_512=$(./task3 "$n" | head -n 1)
    printf '512\t%d\t%s\n' "$n" "$elapsed_512" >> task3_times.tsv

    elapsed_16=$(./task3_16 "$n" | head -n 1)
    printf '16\t%d\t%s\n' "$n" "$elapsed_16" >> task3_times.tsv
done

python3 plot_task3.py task3_times.tsv task3.pdf
