#!/usr/bin/env python3

from snakemake.utils import min_version
import yaml
 
min_version("9.0")


from sc_workflows.helpers import DotDict

# Make more easily-accessible dicts
config = DotDict(config)
slurm = config.slurm
cellranger = config.cellranger
cellbender = config.cellbender

rule run_cellranger:
    input: csv = cellranger.dir + '/{library}/libraries.csv'
    output: bam = cellranger.dir + '/{library}/possorted_genome_bam.bam'
    envmodules: cellranger.module
    params:
        create_bam = cellranger.create_bam,
        transcriptome = cellranger.transcriptome,
        scratch = slurm.scratch_dir,
        mem_gb = int(cellranger.mem_mb / 1100)
    resources:
        slurm_partition = slurm.norm_partition,
        gres = f"lscratch:{cellranger.scratch_gb}",
        cpus_per_task= cellranger.cpus_per_task,
        mem_mb= cellranger.mem_mb,
        runtime= cellranger.runtime,
    script: 'scripts/cellranger.sh'

rule run_cellbender:
    input: raw=cellranger.dir + '/{library}/raw_feature_bc_matrix.h5'
    output: filtered= cellbender.dir + '/{library}/filtered.h5'
    envmodules: cellbender.module
    resources:
        slurm_partition = slurm.gpu_partition,
        gres = f"lscratch:{cellbender.scratch_gb}",
        slurm_extra = slurm.gpu_extra,
        cpus_per_task= cellbender.cpus_per_task,
        mem_mb= cellbender.mem_mb,
        runtime= cellbender.runtime,
    params:
        scratch=slurm.scratch_dir
    script: 'scripts/cellbender.sh'

