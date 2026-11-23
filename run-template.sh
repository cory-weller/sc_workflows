#!/bin/bash
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 1
#SBATCH --mem-per-cpu 8G
#SBATCH --time 48:00:00



module purge
module load snakemake/9.23.1
source myconda

snakemake ${@} \
    --verbose \
    --nolock \
    -p \
    --profile slurm_profile \
    --configfile config.yaml
