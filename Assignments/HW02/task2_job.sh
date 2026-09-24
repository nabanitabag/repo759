#!/usr/bin/env zsh

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH -c 1
#SBATCH -J hw02-task2
#SBATCH -o task2-%j.out
#SBATCH -e task2-%j.err

set -euo pipefail

if (( $# != 2 )); then
    print -u2 "Usage: sbatch task2_job.sh <positive n> <positive odd m>"
    exit 1
fi

cd "$SLURM_SUBMIT_DIR"

g++ convolution.cpp task2.cpp -Wall -O3 -std=c++17 -o task2
./task2 "$1" "$2"
