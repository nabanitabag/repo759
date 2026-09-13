#!/usr/bin/env bash

#SBATCH -p instruction
#SBATCH -t 0-00:03:00

#SBATCH -c 2
#SBATCH -J FirstSlurm
#SBATCH -o FirstSlurm.out -e FirstSlurm.err

cd $SLURM_SUBMIT_DIR
hostname