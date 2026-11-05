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
CHUNKS=${snakemake_params[chunks]}
N=${snakemake_wildcards[chunk]}

N_DONORS=$(awk 'END {print NR-1}' $DONOR_LIST)

cd ${TMPDIR}

# First sort cellsnp output VCF
bcftools sort $CELLSNP_VCF -T /lscratch/${SLURM_JOB_ID}/ -O z -o cells.sorted.vcf.gz 
bcftools index -t cells.sorted.vcf.gz


# Split cellsnp vcf into chunks, first by creating N files with 
echo "Splitting into $CHUNKS chunks"
bcftools query -l cells.sorted.vcf.gz > all_samples.txt
split -n l/${CHUNKS} -d -a 2 --additional-suffix=.txt all_samples.txt samples_chunk_

mkdir output

# # For each chunk:
# for f in samples_chunk_*.txt; do
#     n=${f#samples_chunk_}; n=${n%.txt}
    
#     # For testing, only do first chunk
#     if [[ "$n" > 1 ]]; then
#         continue
#     fi
#     # Delete above section after testing

echo "Working on pulling out chunk_${N}.vcf.gz"
CMD=(bcftools view -S samples_chunk_0$N.txt --force-samples -Oz -o chunk_${N}.vcf.gz cells.sorted.vcf.gz)
echo ${CMD[@]}
${CMD[@]}

bcftools index -t chunk_${N}.vcf.gz

# Run vireo
echo "Running Vireo on chunk_${N}.vcf.gz X $GENOTYPE_VCF"
vireo -c chunk_${N}.vcf.gz -d $GENOTYPE_VCF -o "output" -N ${N_DONORS} --randSeed 2 -p 1
# done

echo "Done with chunk $N"

rsync -av output/* $OUTDIR/
