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
qc = config.qc

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
    output: filtered= cellbender.dir + '/{library}/output_filtered.h5'
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

rule cellbender_apptainer:
    input: raw=cellranger.dir + '/{library}/raw_feature_bc_matrix.h5'
    output: filtered=cellbender.dir + '/{library}/output_filtered.h5'
    resources:
        slurm_partition = slurm.card_patition,
        gres = f"lscratch:{cellbender.scratch_gb}",
        slurm_extra = slurm.nia_extra,
        cpus_per_task= cellbender.cpus_per_task,
        mem_mb= cellbender.mem_mb,
        runtime= cellbender.runtime,
    envmodules: 'apptainer/1.4.5'
    params:
        scratch=slurm.scratch_dir,
        cellbender_sif=cellbender.apptainer,
        apptainer_binds=config.apptainer_binds
    script: 'scripts/apptainer_cellbender.sh'


rule qc_barcodes:
    '''
    generates a list of qc-acceptable barcodes for subsetting prior to freemuxlet
    '''
    input: cellbenderh5=cellbender.dir + '/{library}/output_filtered.h5'
    output: good_bcs=cellbender.dir + '/{library}/qc-barcodes.txt'
    conda: 'envs/python-env.yaml'
    params:
        genes_min = qc.genes_min,
        mito_max = qc.mito_max,
        ribo_max = qc.ribo_max,
        doublet_max = qc.doublet_max
    resources:
        mem_mb = qc.mem_mb
    script: 'scripts/qc-barcodes.py'


# rule extract_qc_barcodes:
#     '''
#     subsets 10x bam to only barcodes in provided text input
#     '''
#     input: 
#         cr_bam=cellranger.dir + '/{library}/possorted_genome_bam.bam',
#         good_bcs=DATA +"/CELLBENDER/{libraryID}/qc-barcodes.txt"
#     output:
#         qc_bam=DATA +"/CELLRANGER/{libraryID}/qc_bam.bam"
#     params:
#         workdir= DATA +"/CELLRANGER/{libraryID}",
#         tenx_subset_binary=DATA +"/subset-bam_linux",
#         somalier_binary=DATA +"/somalier",
#         somalier_sites=DATA +"/sites.hg38.rna.vcf.gz",
#     shell:
#         '''
#         wget https://github.com/10XGenomics/subset-bam/releases/download/v1.1.0/subset-bam_linux
#         cd {params.workdir}
#         {params.tenx_subset_binary} \
#             --bam {input.cr_bam} \
#             --cores {resources.cpus_per_task} \
#             --cell-barcodes {input.good_bcs} \
#             --out-bam {output.qc_bam}
#         '''