#!/usr/bin/env zsh

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH -c 1
#SBATCH -J hw02-task3
#SBATCH -o task3-%j.out
#SBATCH -e task3-%j.err

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"

g++ matmul.cpp task3.cpp -Wall -O3 -std=c++17 -o task3
./task3
