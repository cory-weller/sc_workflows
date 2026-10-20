#!/usr/bin/env bash

# Define scratch directory by expanding snakemake param value:
export TMPDIR=$(envsubst <<< ${snakemake_params[scratch]})
echo "Temporary working directory: $TMPDIR"

# Get full path name for outputs
INH5=$(readlink -e ${snakemake_input[raw]})
OUTDIR=$(dirname $(readlink -m ${snakemake_output[filtered]}))


# Work in temporary dir
cd $TMPDIR || exit 1
TMPDIR=$PWD

echo in directory $PWD
echo $(ls -la "$PWD")
#touch test-file.txt

module load apptainer

export APPTAINER_BINDPATH="${snakemake_params[apptainer_binds]}"

# Build command from snakemake input and output
CMD=(apptainer exec ${snakemake_params[cellbender_sif]} cellbender remove-background \
    --cuda \
    --input $INH5 \
    --output output.h5)

# Print command to terminal for log
echo ${CMD[@]}

# Run command
${CMD[@]}

# Copy outputs to permanent storage
OUT_FILES=(
output_report.html
output.h5
output_filtered.h5
output_cell_barcodes.csv
output.log
output_metrics.csv
)

mv ${OUT_FILES[@]} $OUTDIR/

