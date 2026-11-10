#!/usr/bin/env bash
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --job-name=hisat2_index
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=/data/users/nireddy/rnaseq_project/logs/%x_%j.out
#SBATCH --error=/data/users/nireddy/rnaseq_project/logs/%x_%j.err
set -euo pipefail

source /data/users/${USER}/rnaseq_project/scripts/config.sh

[ -s "$GENOME_FA" ] || { echo "[error] genome FASTA missing: $GENOME_FA" >&2; exit 1; }
mkdir -p "$HISAT2_INDEX_DIR"

echo "[info] $(date -Iseconds) start hisat2-build on $(hostname), ${SLURM_CPUS_PER_TASK} threads"

apptainer exec --bind "${APPTAINER_BIND}" "${HISAT2_SIF}" \
    hisat2-build -p "${SLURM_CPUS_PER_TASK}" \
                 "${GENOME_FA}" \
                 "${HISAT2_INDEX}"

apptainer exec --bind "${APPTAINER_BIND}" "${HISAT2_SIF}" hisat2-build --version \
    | head -1 > "${HISAT2_INDEX_DIR}/hisat2_version.txt"

ls -lh "${HISAT2_INDEX_DIR}"
echo "[done] $(date -Iseconds) index: ${HISAT2_INDEX}.*.ht2"
