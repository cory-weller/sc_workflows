#!/usr/bin/env bash

bam=$(readlink -e ${snakemake_input[bam]})
good_bcs=$(readlink -e ${snakemake_input[good_bcs]})
tenx_subset_binary=$(readlink -e ${snakemake_input[tenx_subset_binary]})
qc_bam=$(readlink -m ${snakemake_output[qc_bam]})


echo $bam
echo $good_bcs
echo $tenx_subset_binary
echo $qc_bam

export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})

echo $TMPDIR

cd $TMPDIR

${tenx_subset_binary} \
    --bam ${bam} \
    --cores ${snakemake_resources[cpus_per_task]} \
    --cell-barcodes ${good_bcs} \
    --out-bam output.bam

mv output.bam ${qc_bam}

echo 'done'

exit 0