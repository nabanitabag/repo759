#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:10:00
#SBATCH --ntasks=1 --gpus-per-task=1 -c 1
#SBATCH --mem=8G
#SBATCH -J hw06-task1
#SBATCH -o task1-%j.out
#SBATCH -e task1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

# Optional arguments: sbatch task1_job.sh [n] [threads_per_block]
n=${1:-1024}
threads_per_block=${2:-256}

module load nvidia/cuda

nvcc task1.cu matmul.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task1

./task1 "$n" "$threads_per_block"
