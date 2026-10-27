#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:30:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=2G
#SBATCH -J hw04-task3
#SBATCH -o task3-%j.out
#SBATCH -e task3-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

if [[ $# -ne 3 ]]; then
    echo "Usage: sbatch $0 <number_of_particles> <simulation_end_time> <num_threads>" >&2
    exit 1
fi

if (( $3 > SLURM_CPUS_PER_TASK )); then
    echo "num_threads ($3) exceeds allocated CPUs ($SLURM_CPUS_PER_TASK)." >&2
    exit 1
fi

g++ task3.cpp -Wall -O3 -std=c++17 -o task3 -fopenmp

export OMP_DYNAMIC=FALSE
export OMP_PLACES=cores
export OMP_PROC_BIND=close

./task3 "$1" "$2" "$3"