#!/usr/bin/env bash

export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})

# Extract donors from VCF

GENOTYPE_VCF=$(readlink -e ${snakemake_input[genotypes_vcf]})
CELLSNP_VCF=$(readlink -e ${snakemake_input[cellsnp_vcf]})
DONOR_LIST=$(readlink -e ${snakemake_input[donor_list]})
OUTFILE=$(readlink -m ${snakemake_output[out]})
OUTDIR=$(dirname $OUTFILE)





# Scratch
cd $TMPDIR

# copy donor list to temporary dir, skip line 1 which is `sample_id` header
# And replace text from BLM0 to end of line






bcftools view $GENOTYPE_VCF -R $CELLSNP_VCF -Oz -o sub.vcf.gz

vireo -c sub.vcf.gz -d $GENOTYPE_VCF -o output

vireo -c $CELLSNP_VCF -d $GENOTYPE_VCF -o output -N ${snakemake_resources[cpus_per_task]} --randSeed 2


rsync -av output/* $OUTDIR/
