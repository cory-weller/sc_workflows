#!/usr/bin/env bash

export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})
#export TMPDIR=$(envsubst <<< ${snakemake_params[perm_scratch]})
mkdir -p ${TMPDIR}

# Extract donors from VCF

GENOTYPE_VCF=$(readlink -e ${snakemake_input[genotypes_vcf]})
CELLSNP_VCF=$(readlink -e ${snakemake_input[cellsnp_vcf]})
DONOR_LIST=$(readlink -e ${snakemake_input[donor_list]})
OUTFILE=$(readlink -m ${snakemake_output[out]})
OUTDIR=$(dirname $OUTFILE)

N_DONORS=$(awk 'END {print NR}' $DONOR_LIST)

cd ${TMPDIR}

mkdir output

# Subset DONOR VCF to only provided donor list
bcftools view -S ${DONOR_LIST} --force-samples ${GENOTYPE_VCF} -Oz -o genotype_subset.vcf.gz


# Run vireo
echo "Running Vireo on ${CELLSNP_VCF} X genotype_subset.vcf.gz"
vireo -c ${CELLSNP_VCF} -d genotype_subset.vcf.gz -o "output" -N ${N_DONORS} --randSeed 2 -p 1


rsync -av output/* $OUTDIR/
