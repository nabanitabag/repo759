#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH --cpus-per-task=20
#SBATCH --mem=10G
#SBATCH -J hw03-task3
#SBATCH -o task3-%j.out
#SBATCH -e task3-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

g++ task3.cpp msort.cpp -Wall -O3 -std=c++17 -o task3 -fopenmp
# Check the dependency-free plotting helper before running the sweeps.
python3 -c 'import plot_task3'

export OMP_DYNAMIC=FALSE
export OMP_PLACES=cores
export OMP_PROC_BIND=close

printf 'threshold\ttime_ms\n' > task3_ts_times.tsv
for exponent in {1..10}; do
    threshold=$((1 << exponent))
    result=$(./task3 1000000 8 "$threshold")
    elapsed_ms=$(printf '%s\n' "$result" | tail -n 1)
    printf '%d\t%s\n' "$threshold" "$elapsed_ms" >> task3_ts_times.tsv
done

best_threshold=$(python3 plot_task3.py threshold task3_ts_times.tsv task3_ts.pdf)
printf '%s\n' "$best_threshold" > task3_best_threshold.txt
printf 'Best threshold: %s\n' "$best_threshold"

printf 'threads\ttime_ms\n' > task3_t_times.tsv
for threads in {1..20}; do
    result=$(./task3 1000000 "$threads" "$best_threshold")
    elapsed_ms=$(printf '%s\n' "$result" | tail -n 1)
    printf '%d\t%s\n' "$threads" "$elapsed_ms" >> task3_t_times.tsv
done

python3 plot_task3.py threads task3_t_times.tsv task3_t.pdf "$best_threshold"
