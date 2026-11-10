#!/usr/bin/env bash
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --job-name=multiqc
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --output=/data/users/nireddy/rnaseq_project/logs/%x_%j.out
#SBATCH --error=/data/users/nireddy/rnaseq_project/logs/%x_%j.err
set -euo pipefail

source /data/users/${USER}/rnaseq_project/scripts/config.sh

mkdir -p "${MULTIQC_DIR}"

# Scans all of results/ (FastQC now; HISAT2 + featureCounts summaries later)
apptainer exec --bind "${APPTAINER_BIND}" "${MULTIQC_SIF}" \
    multiqc --force \
            --outdir "${MULTIQC_DIR}" \
            --ignore "${MULTIQC_DIR}" \
            "${RESULTS_DIR}"

echo "[done] report: ${MULTIQC_DIR}/multiqc_report.html"
