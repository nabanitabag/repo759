#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:05:00
#SBATCH --gpus-per-task=1 -c 1
#SBATCH --mem=1G
#SBATCH -J hw05-task1
#SBATCH -o task1-%j.out
#SBATCH -e task1-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module load nvidia/cuda

nvcc task1.cu -Xcompiler -O3 -Xcompiler -Wall -Xptxas -O3 -std=c++17 -o task1

./task1
