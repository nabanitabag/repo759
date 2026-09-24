#!/usr/bin/env zsh

#SBATCH -p instruction
#SBATCH -t 0-00:01:00
#SBATCH -c 1
#SBATCH -J hw02-task1-plot
#SBATCH -o task1-plot-%j.out
#SBATCH -e task1-plot-%j.err

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"
python3 plot_task1.py task1_times.tsv task1.pdf
