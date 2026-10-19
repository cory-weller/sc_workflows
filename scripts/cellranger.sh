#!/usr/bin/env bash

# Define scratch directory by expanding snakemake param value:
export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})
echo "Temporary working directory will be: $TMPDIR"

# Get full path to output bam (and its directory)
OUTBAM=$(readlink -m ${snakemake_output[bam]})
OUTDIR=$(dirname $OUTBAM)

# Get full path to output bam (and its directory)

INCSV=$(readlink -e ${snakemake_input[csv]})

# Create scratch directory and copy input 
mkdir -p $TMPDIR
cp $INCSV $TMPDIR && cd $TMPDIR

CMD=(cellranger count \
    --id ${snakemake_wildcards[library]} \
    --create-bam true \
    --localcores ${snakemake_resources[cpus_per_task]} \
    --localmem ${snakemake_params[mem_gb]} \
    --libraries $(basename ${snakemake_input[csv]}) \
    --transcriptome ${snakemake_params[transcriptome]} \
    --disable-cell-annotation \
    --nosecondary)
    
echo ${CMD[@]}

cd $TMPDIR

${CMD[@]}

# Only create output directory if cellranger succeeded
mkdir -p $OUTDIR

# Move contents from cellranger/outs to permanent disk location
cp -r ${snakemake_wildcards[library]}/outs/. $OUTDIR/

