#!/usr/bin/env bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR=$(dirname $SCRIPT_DIR)

FILES=("${PARENT_DIR}/Snakefile" "${PARENT_DIR}/config.yaml" "${PARENT_DIR}/run.sh" "${PARENT_DIR}/slurm_profile/config.yaml")

bad_checks=0

for file in ${FILES[@]}; do
    if [[ -f "${file}" ]]; then
        echo "WARNING: $file already exists"
        let bad_checks=$bad_checks+1
    fi
done

if [[ "${bad_checks}" -gt 0 ]]; then
    echo "Template files not copied due to one or more files existing in the parent folder."
    echo "Remove or rename these files first and re-run this script if desired."
    exit 1
else
    cp -r "${SCRIPT_DIR}/orchestrator_templates/." ${PARENT_DIR}
fi
