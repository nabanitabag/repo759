#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:30:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=2G
#SBATCH -J hw04-task4
#SBATCH -o task4-%j.out
#SBATCH -e task4-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

# Optional arguments: sbatch task4_job.sh [number_of_particles] [simulation_end_time]
particles=${1:-1000}
end_time=${2:-100}

g++ task3.cpp -Wall -O3 -std=c++17 -o task3 -fopenmp

export OMP_DYNAMIC=FALSE
export OMP_PLACES=cores
export OMP_PROC_BIND=close

printf 'policy\tthreads\ttime_ms\n' > task4_times.tsv
for policy in static dynamic guided; do
    export OMP_SCHEDULE="$policy"
    for threads in {1..8}; do
        result=$(./task3 "$particles" "$end_time" "$threads")
        elapsed_ms=$(printf '%s\n' "$result" | tail -n 1 | sed -e 's/^time: //' -e 's/ms$//')
        printf '%s\t%d\t%s\n' "$policy" "$threads" "$elapsed_ms" >> task4_times.tsv
        printf '%s, %d threads: %s ms\n' "$policy" "$threads" "$elapsed_ms"
    done
done

python3 plot_task4.py task4_times.tsv task4.pdf "$particles" "$end_time"
