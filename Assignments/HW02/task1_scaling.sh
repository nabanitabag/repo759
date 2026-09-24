#!/usr/bin/env zsh

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH -c 1
#SBATCH --mem=10G
#SBATCH -J hw02-task1-scaling
#SBATCH -o task1-scaling-%j.out
#SBATCH -e task1-scaling-%j.err

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"

g++ scan.cpp task1.cpp -Wall -O3 -std=c++17 -o task1

printf "n\ttime_ms\n" > task1_times.tsv
for exponent in {10..30}; do
    n=$((1 << exponent))
    result=$(./task1 "$n")
    elapsed_ms=${result%%$'\n'*}
    printf "%d\t%s\n" "$n" "$elapsed_ms" >> task1_times.tsv
done

python3 plot_task1.py task1_times.tsv task1.pdf
