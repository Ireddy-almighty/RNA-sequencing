#!/usr/bin/env bash
# config.sh - project variables only. Source at the top of every script:
#   source /data/users/${USER}/rnaseq_project/scripts/config.sh

WORKING_DIR=/data/users/${USER}/rnaseq_project
SCRIPTS_DIR=${WORKING_DIR}/scripts
SLURM_ACCOUNT=class-467713-ws-2026
SLURM_PARTITION=pshort_el8
LOG_DIR=${WORKING_DIR}/logs

RAW_DATA_SRC=/data/courses/rnaseq_course/toxoplasma_de/reads_Lung
RAW_DATA_DIR=${WORKING_DIR}/raw_data
METADATA_FILE=${WORKING_DIR}/metadata/metadata.csv

ENSEMBL_RELEASE=116
ASSEMBLY=GRCm39
REF_DIR=${WORKING_DIR}/reference/ensembl_${ENSEMBL_RELEASE}
GENOME_FA=${REF_DIR}/Mus_musculus.${ASSEMBLY}.dna.primary_assembly.fa
ANNOTATION_GTF=${REF_DIR}/Mus_musculus.${ASSEMBLY}.${ENSEMBL_RELEASE}.gtf
HISAT2_INDEX_DIR=${REF_DIR}/hisat2_index
HISAT2_INDEX=${HISAT2_INDEX_DIR}/${ASSEMBLY}

HISAT2_STRAND=RF
FC_STRAND=2

RESULTS_DIR=${WORKING_DIR}/results
FASTQC_DIR=${RESULTS_DIR}/01_fastqc
MULTIQC_DIR=${RESULTS_DIR}/02_multiqc
BAM_DIR=${RESULTS_DIR}/03_hisat2
COUNTS_DIR=${RESULTS_DIR}/04_featurecounts

IBU_CONTAINERS=/containers/apptainer
FASTQC_SIF=${IBU_CONTAINERS}/fastqc-0.12.1.sif
HISAT2_SIF=${IBU_CONTAINERS}/hisat2_samtools_408dfd02f175cd88.sif
SUBREAD_SIF=${IBU_CONTAINERS}/subread_2.0.6.sif
CONTAINER_DIR=${WORKING_DIR}/containers
MULTIQC_SIF=${IBU_CONTAINERS}/multiqc-1.33.sif
APPTAINER_BIND=/data

SAMPLE_ID_LIST=()
if [ -d "${RAW_DATA_DIR}/" ]; then
    SAMPLE_ID_LIST=($(for f in "${RAW_DATA_DIR}"/*.fastq.gz; do
                          basename "$f" | cut -d_ -f1
                      done | sort -u))
fi
