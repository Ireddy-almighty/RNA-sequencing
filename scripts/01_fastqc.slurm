#!/usr/bin/env bash

#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --job-name=fastqc
#SBATCH --cpus-per-task=2
#SBATCH --mem=2G
#SBATCH --time=01:00:00
#SBATCH --output=/data/users/nireddy/rnaseq_project/logs/%x_%A_%a.out
#SBATCH --error=/data/users/nireddy/rnaseq_project/logs/%x_%A_%a.err
set -euo pipefail

source /data/users/${USER}/rnaseq_project/scripts/config.sh

SAMPLE=${SAMPLE_ID_LIST[$SLURM_ARRAY_TASK_ID]}
OUT_DIR=${FASTQC_DIR}/${SAMPLE}
mkdir -p "$OUT_DIR"

echo "[info] task ${SLURM_ARRAY_TASK_ID}: sample ${SAMPLE} on $(hostname)"

apptainer exec --bind "${APPTAINER_BIND}" "${FASTQC_SIF}" \
    fastqc --threads "${SLURM_CPUS_PER_TASK}" \
           --outdir "${OUT_DIR}" \
           "${RAW_DATA_DIR}/${SAMPLE}_1.fastq.gz" \
           "${RAW_DATA_DIR}/${SAMPLE}_2.fastq.gz"

echo "[done] ${SAMPLE}"
