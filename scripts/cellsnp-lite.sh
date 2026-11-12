#!/usr/bin/env bash

OUTVCF=$(readlink -m ${snakemake_output[vcf]})
OUTDIR=$(dirname $OUTVCF)

BCFILE=$(readlink -e ${snakemake_input[good_bcs]})
BAMFILE=$(readlink -e ${snakemake_input[qc_bam]})
VARIANTVCF=$(readlink -e ${snakemake_input[variant_vcf]})

export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})
cd $TMPDIR

echo "beginning cellsnp-lite in $PWD"

CMD=(cellsnp-lite \
    -p ${snakemake_resources[cpus_per_task]} \
    -R $VARIANTVCF \
    -s $BAMFILE \
    --genotype \
    -O cellSNP \
    -b $BCFILE \
    --minMAF ${snakemake_params[min_MAF]} \
    --minCOUNT ${snakemake_params[min_count]} \
    --gzip)

echo ${CMD[@]}

${CMD[@]}

# Sort cellsnp output, because for some reason it doesn't do it
bcftools sort cellSNP/cellSNP.cells.vcf.gz -O z -o cellSNP/cellSNP.cells.sorted.vcf.gz
bcftools index -t cellSNP/cellSNP.cells.sorted.vcf.gz
rm cellSNP/cellSNP.cells.vcf.gz

echo "moving output to $OUTDIR"


rsync -av cellSNP/* $OUTDIR/