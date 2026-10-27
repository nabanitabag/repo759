#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH -J hw04-task2
#SBATCH -o task2-%j.out
#SBATCH -e task2-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

if [[ $# -ne 2 ]]; then
    echo "Usage: sbatch $0 <number_of_particles> <simulation_end_time>" >&2
    exit 1
fi

g++ task2.cpp -Wall -O3 -std=c++17 -o task2

./task2 "$1" "$2"
