#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-01:00:00
#SBATCH --ntasks=1 --gpus-per-task=1 -c 1
#SBATCH --mem=8G
#SBATCH -J hw07-task1
#SBATCH -o task1-%j.out
#SBATCH -e task1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module load nvidia/cuda

nvcc task1.cu matmul.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task1

# Untimed warm-up so one-time GPU startup cost doesn't land on the first data point.
./task1 32 16 > /dev/null

# Part (c): find the fastest block_dim at n = 2^14 (by total int + float + double time).
printf 'block_dim\tint_ms\tfloat_ms\tdouble_ms\n' > task1_block_dim.tsv
best_block_dim=""
best_total=""
for block_dim in 8 16 32; do
    times=$(./task1 16384 "$block_dim" | sed -n '3p;6p;9p' | paste -sd '\t' -)
    printf '%d\t%s\n' "$block_dim" "$times" >> task1_block_dim.tsv
    printf 'n = 16384, block_dim = %d: int/float/double = %s ms\n' "$block_dim" "$times"
    total=$(printf '%s\n' "$times" | awk -F'\t' '{print $1 + $2 + $3}')
    if [ -z "$best_total" ] || awk -v a="$total" -v b="$best_total" 'BEGIN { exit !(a < b) }'; then
        best_total=$total
        best_block_dim=$block_dim
    fi
done
printf 'Best block_dim at n = 16384: %d\n' "$best_block_dim"

# Part (b): time vs. n using the best block_dim.
printf 'type\tn\ttime_ms\n' > task1_times.tsv
for exponent in {5..14}; do
    n=$((2 ** exponent))
    times=($(./task1 "$n" "$best_block_dim" | sed -n '3p;6p;9p'))
    printf 'int\t%d\t%s\nfloat\t%d\t%s\ndouble\t%d\t%s\n' \
        "$n" "${times[0]}" "$n" "${times[1]}" "$n" "${times[2]}" >> task1_times.tsv
    printf 'n = %d: int/float/double = %s / %s / %s ms\n' "$n" "${times[0]}" "${times[1]}" "${times[2]}"
done

python3 plot_task1.py task1_times.tsv task1.pdf "$best_block_dim"
