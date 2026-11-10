#!/usr/bin/env bash
#SBATCH --partition=pshort_el8
#SBATCH --job-name=setup_reference
#SBATCH --account=class-467713-ws-2026
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=/data/users/nireddy/rnaseq_project/logs/%x_%j.out
#SBATCH --error=/data/users/nireddy/rnaseq_project/logs/%x_%j.err
# set_up.sh - one-off project setup: folders, raw_data link,
# Ensembl genome + GTF with checksum check, containers, provenance.
set -euo pipefail

source /data/users/${USER}/rnaseq_project/scripts/config.sh

mkdir -p "$LOG_DIR" "$(dirname "$METADATA_FILE")" "$REF_DIR" "$HISAT2_INDEX_DIR" \
         "$FASTQC_DIR" "$MULTIQC_DIR" "$BAM_DIR" "$COUNTS_DIR" "$CONTAINER_DIR"

if [ ! -e "$RAW_DATA_DIR" ]; then
    ln -s "$RAW_DATA_SRC" "$RAW_DATA_DIR"
fi
n_fastq=$(ls "$RAW_DATA_DIR"/*.fastq.gz | wc -l)
echo "[ok] raw_data -> $RAW_DATA_SRC  ($n_fastq fastq.gz files)"

ENSEMBL_BASE=https://ftp.ensembl.org/pub/release-${ENSEMBL_RELEASE}
FASTA_URL_DIR=${ENSEMBL_BASE}/fasta/mus_musculus/dna
GTF_URL_DIR=${ENSEMBL_BASE}/gtf/mus_musculus

if ! wget -q --spider "${GTF_URL_DIR}/CHECKSUMS"; then
    echo "[error] cannot reach ${GTF_URL_DIR}/CHECKSUMS (no internet on node, or release missing)" >&2
    exit 1
fi

current_gtf=$(wget -qO- https://ftp.ensembl.org/pub/current_gtf/mus_musculus/ \
              | grep -o 'Mus_musculus\.GRCm39\.[0-9]*\.gtf\.gz' | sort -u | head -1 || true)
echo "[info] Using release ${ENSEMBL_RELEASE}; Ensembl 'current' GTF: ${current_gtf:-unknown}"

cd "$REF_DIR"

download_verify () {
    local url_dir=$1 gz=$2 final=$3 tag=$4
    if [ -s "$final" ]; then
        echo "[skip] $(basename "$final") already present"
        return
    fi
    wget -q -O "CHECKSUMS_${tag}" "${url_dir}/CHECKSUMS"
    wget -q -c "${url_dir}/${gz}"
    local expected observed
    expected=$(awk -v f="$gz" '$3==f {print $1+0, $2+0}' "CHECKSUMS_${tag}")
    observed=$(sum "$gz" | awk '{print $1+0, $2+0}')
    if [ -z "$expected" ]; then
        echo "[error] $gz not listed in CHECKSUMS_${tag}" >&2; exit 1
    fi
    if [ "$expected" != "$observed" ]; then
        echo "[error] checksum mismatch for $gz: expected '$expected', got '$observed'" >&2
        rm -f "$gz"; exit 1
    fi
    echo "[ok] checksum $gz: $observed"
    printf '%s\texpected=%s\tobserved=%s\n' "$gz" "$expected" "$observed" >> checksums_verified.tsv
    gunzip "$gz"
}

download_verify "$FASTA_URL_DIR" "$(basename "$GENOME_FA").gz"      "$GENOME_FA"      fasta
download_verify "$GTF_URL_DIR"   "$(basename "$ANNOTATION_GTF").gz" "$ANNOTATION_GTF" gtf

for sif in "$FASTQC_SIF" "$HISAT2_SIF" "$SUBREAD_SIF"; do
    [ -f "$sif" ] || { echo "[error] missing container $sif" >&2; exit 1; }
done
if [ ! -f "$MULTIQC_SIF" ]; then
    apptainer pull "$MULTIQC_SIF" docker://quay.io/biocontainers/multiqc:1.32--pyhdfd78af_1
fi
echo "[ok] containers available"

{
    echo "date_downloaded: $(date -Iseconds)"
    echo "ensembl_release: ${ENSEMBL_RELEASE}"
    echo "assembly:        ${ASSEMBLY}"
    echo "genome_fasta:    ${FASTA_URL_DIR}/$(basename "$GENOME_FA").gz"
    echo "annotation_gtf:  ${GTF_URL_DIR}/$(basename "$ANNOTATION_GTF").gz"
    echo "ensembl_current_gtf_at_download: ${current_gtf:-unknown}"
} > "${REF_DIR}/PROVENANCE.txt"

GITIGNORE=${WORKING_DIR}/.gitignore
touch "$GITIGNORE"
for pattern in raw_data reference/ results/ containers/ logs/ \
               '*.sif' '*.bam' '*.bai' '*.sam' '*.fastq.gz' '*.fa' '*.fai' '*.gtf' '*.ht2'; do
    grep -qxF "$pattern" "$GITIGNORE" || echo "$pattern" >> "$GITIGNORE"
done

echo "[done] Setup complete. Provenance: ${REF_DIR}/PROVENANCE.txt"
