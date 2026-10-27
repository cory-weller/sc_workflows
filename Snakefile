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
qc_extract = config.qc_extract
cellsnp = config.cellsnp
vireo = config.vireo

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

rule download_10x_subset_binary:
    '''
    downloads subset-bam_linux from github
    '''
    output: tenx_subset_binary=cellbender.dir + '/subset-bam_linux'
    params: link = 'https://github.com/10XGenomics/subset-bam/releases/download/v1.1.0/subset-bam_linux'
    shell:
        '''
        wget -P {config.cellbender.dir}/ {params.link} 
        chmod +x {output}
        '''

rule extract_qc_barcodes:
    '''
    subsets 10x bam to only barcodes in provided text input
    '''
    input: 
        bam = cellranger.dir + '/{library}/possorted_genome_bam.bam',
        good_bcs=cellbender.dir + '/{library}/qc-barcodes.txt',
        tenx_subset_binary=cellbender.dir + '/subset-bam_linux'
    output:
        qc_bam = cellranger.dir + '_QC/{library}/possorted_genome_bam.bam'
    params:
        scratch=slurm.scratch_dir,
    resources:
        gres            = f"lscratch:{cellbender.scratch_gb}",
        cpus_per_task   = qc_extract.cpus_per_task,
        mem_mb          = qc_extract.mem_mb,
        runtime         = qc_extract.runtime,
        slurm_partition       = qc_extract.partition
    script: 'scripts/extract_qc_barcodes.sh'


rule download_variants:
    '''
    downloads hg38 list of 7.4M SNPs with minor allele frequency (MAF) > 0.05
    '''
    output: variant_vcf=cellbender.dir + '/genome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz'
    params: link = 'https://downloads.sourceforge.net/project/cellsnp/SNPlist/genome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz?ts=gAAAAABq21sviO-5LbOYEPzRReat1QUDD3Hdtj95e7DB13ajy2_BuQxYVdrDk4881BDw1YhHlzOcyqXkoU4jPtf1P3GdkQ2s3A%3D%3D&r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fcellsnp%2Ffiles%2FSNPlist%2Fgenome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz%2Fdownload'
    shell:
        '''
        wget -O {output} {params.link} 
        '''

rule cellsnplite:
    '''
    generates pileup for 10x data
    Mode 2a: droplet based single cells without given SNPs (infer variants from pileup)
    '''
    input: 
        qc_bam = cellranger.dir + '/{library}/possorted_genome_bam.bam',
        variant_vcf=cellbender.dir + '/genome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz',
        good_bcs=cellbender.dir + '/{library}/qc-barcodes.txt'
    output:
        vcf = cellranger.dir + '_QC/{library}/cellSNP/cellSNP.cells.vcf.gz'
    conda: 'envs/python-env.yaml'
    params:
        scratch=slurm.scratch_dir,
        min_MAF=0.1,
        min_count=20
    resources:
        gres            = f"lscratch:{cellsnp.scratch_gb}",
        cpus_per_task   = cellsnp.cpus_per_task,
        mem_mb          = cellsnp.mem_mb,
        runtime         = cellsnp.runtime,
        slurm_partition = cellsnp.partition
    script: 'scripts/cellsnp-lite.sh'

rule vireo:
    '''
    generates pileup for 10x data
    Mode 2a: droplet based single cells without given SNPs (infer variants from pileup)
    '''
    input: 
        genotypes_vcf = vireo.dir + '/genotypes.vcf.gz',
        cellsnp_vcf = cellranger.dir + '_QC/{library}/cellSNP/cellSNP.cells.vcf.gz',
        donor_list = config.preprocess.reads_organized + '/{library}/provided_sample_list.txt'
    output:
        out=config.vireo.dir +'/{library}/donor_ids.tsv'
    conda: 'envs/python-env.yaml'
    params:
        scratch=slurm.scratch_dir,
    resources:
        gres                = f"lscratch:{vireo.scratch_gb}",
        cpus_per_task       = vireo.cpus_per_task,
        mem_mb              = vireo.mem_mb,
        runtime             = vireo.runtime,
        slurm_partition     = vireo.partition
    script: 'scripts/vireo.sh'
