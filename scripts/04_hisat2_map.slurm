#!/usr/bin/env bash
#SBATCH --partition=pshort_el8
#SBATCH --account=class-467713-ws-2026
#SBATCH --job-name=hisat2_map
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --time=02:00:00
#SBATCH --output=/data/users/nireddy/rnaseq_project/logs/%x_%A_%a.out
#SBATCH --error=/data/users/nireddy/rnaseq_project/logs/%x_%A_%a.err
#SBATCH --array=0-14
set -euo pipefail

source /data/users/${USER}/rnaseq_project/scripts/config.sh

SAMPLE=${SAMPLE_ID_LIST[$SLURM_ARRAY_TASK_ID]}
THREADS=${SLURM_CPUS_PER_TASK}
SORT_THREADS=2
SORT_MEM=2G

R1=${RAW_DATA_DIR}/${SAMPLE}_1.fastq.gz
R2=${RAW_DATA_DIR}/${SAMPLE}_2.fastq.gz
BAM=${BAM_DIR}/${SAMPLE}.sorted.bam
SUMMARY=${BAM_DIR}/${SAMPLE}.hisat2.summary
TMP=${BAM_DIR}/tmp_${SAMPLE}

ls "${HISAT2_INDEX}".1.ht2 > /dev/null || { echo "[error] HISAT2 index missing" >&2; exit 1; }
mkdir -p "$BAM_DIR" "$TMP"

echo "[info] $(date -Iseconds) ${SAMPLE} on $(hostname), ${THREADS} threads"

apptainer exec --bind "${APPTAINER_BIND}" "${HISAT2_SIF}" bash -c "
  set -euo pipefail
  hisat2 -p ${THREADS} \
         -x ${HISAT2_INDEX} \
         -1 ${R1} -2 ${R2} \
         --rna-strandness ${HISAT2_STRAND} \
         --summary-file ${SUMMARY} \
  | samtools sort -@ ${SORT_THREADS} -m ${SORT_MEM} -T ${TMP}/${SAMPLE} \
                  -o ${BAM}##idx##${BAM}.bai --write-index -
"

rm -rf "$TMP"

apptainer exec --bind "${APPTAINER_BIND}" "${HISAT2_SIF}" samtools quickcheck "${BAM}" \
    && echo "[ok] ${BAM} passes samtools quickcheck"

cat "${SUMMARY}"
echo "[done] $(date -Iseconds) ${SAMPLE}"
