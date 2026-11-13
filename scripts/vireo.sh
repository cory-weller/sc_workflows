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


# Split cellsnp vcf into chunks, first by creating N files with 
echo "Splitting into $CHUNKS chunks"
bcftools query -l ${CELLSNP_VCF} > all_samples.txt
split -n l/${CHUNKS} -d -a 2 --additional-suffix=.txt all_samples.txt samples_chunk_

mkdir output


echo "Working on pulling out chunk_${N}.vcf.gz"
CMD=(bcftools view -S samples_chunk_0$N.txt --force-samples -Oz -o chunk_${N}.vcf.gz ${CELLSNP_VCF})
echo ${CMD[@]}
${CMD[@]}

bcftools index -t chunk_${N}.vcf.gz

# Run vireo
echo "Running Vireo on chunk_${N}.vcf.gz X $GENOTYPE_VCF"
vireo -c chunk_${N}.vcf.gz -d $GENOTYPE_VCF -o "output" -N ${N_DONORS} --randSeed 2 -p 1
# done

echo "Done with chunk $N"

rsync -av output/* $OUTDIR/
