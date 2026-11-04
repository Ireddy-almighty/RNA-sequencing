#!/usr/bin/env bash
# =============================================================================
# 00_get_reference.sh — one-off project setup. Run ONCE on the login node:
#   bash /data/users/${USER}/rnaseq_project/scripts/00_get_reference.sh
#
# 1. Creates the directory structure
# 2. Symlinks the raw reads (no copying)
# 3. Downloads the Ensembl genome (primary assembly) + GTF and verifies them
#    against Ensembl CHECKSUMS (BSD `sum`), as required in course section 3
# 4. Pulls the MultiQC container
# 5. Writes a provenance file and extends .gitignore
# Safe to re-run: finished steps are skipped.
# =============================================================================
set -euo pipefail

source "$(dirname "$(readlink -f "$0")")/config.sh"

## ---- 1. Directories --------------------------------------------------------
mkdir -p "$LOG_DIR" "$(dirname "$METADATA_FILE")" "$REF_DIR" "$HISAT2_INDEX_DIR" \
         "$FASTQC_DIR" "$MULTIQC_DIR" "$BAM_DIR" "$COUNTS_DIR" "$CONTAINER_DIR"

## ---- 2. Raw data symlink ---------------------------------------------------
if [ ! -e "$RAW_DATA_DIR" ]; then
    ln -s "$RAW_DATA_SRC" "$RAW_DATA_DIR"
fi
n_fastq=$(ls "$RAW_DATA_DIR"/*.fastq.gz | wc -l)
echo "[ok] raw_data -> $RAW_DATA_SRC  ($n_fastq fastq.gz files)"

## ---- 3. Reference download + checksum verification -------------------------
ENSEMBL_BASE=https://ftp.ensembl.org/pub/release-${ENSEMBL_RELEASE}
FASTA_URL_DIR=${ENSEMBL_BASE}/fasta/mus_musculus/dna
GTF_URL_DIR=${ENSEMBL_BASE}/gtf/mus_musculus

# Fail early with a clear message if the release does not exist
if ! wget -q --spider "${GTF_URL_DIR}/CHECKSUMS"; then
    echo "[error] Ensembl release ${ENSEMBL_RELEASE} not found at ${ENSEMBL_BASE}" >&2
    echo "        Check available releases: https://ftp.ensembl.org/pub/" >&2
    exit 1
fi

# Report what Ensembl currently labels as 'current' (for the 'latest' requirement)
current_gtf=$(wget -qO- https://ftp.ensembl.org/pub/current_gtf/mus_musculus/ \
              | grep -o 'Mus_musculus\.GRCm39\.[0-9]*\.gtf\.gz' | sort -u | head -1 || true)
echo "[info] Using release ${ENSEMBL_RELEASE}; Ensembl 'current' GTF: ${current_gtf:-unknown}"

cd "$REF_DIR"

# download_verify <url_dir> <file.gz> <final_uncompressed_path> <checksum_tag>
download_verify () {
    local url_dir=$1 gz=$2 final=$3 tag=$4
    if [ -s "$final" ]; then
        echo "[skip] $(basename "$final") already present"
        return
    fi
    wget -q -O "CHECKSUMS_${tag}" "${url_dir}/CHECKSUMS"
    wget -q -c "${url_dir}/${gz}"

    # Ensembl CHECKSUMS = output of BSD `sum`: <checksum> <blocks> <file>
    # +0 strips zero padding so formats compare numerically
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
    echo "${gz}	expected=${expected}	observed=${observed}" >> checksums_verified.tsv

    gunzip "$gz"
}

download_verify "$FASTA_URL_DIR" "$(basename "$GENOME_FA").gz"      "$GENOME_FA"      fasta
download_verify "$GTF_URL_DIR"   "$(basename "$ANNOTATION_GTF").gz" "$ANNOTATION_GTF" gtf

## ---- 4. Containers ---------------------------------------------------------
for sif in "$FASTQC_SIF" "$HISAT2_SIF" "$SUBREAD_SIF"; do
    [ -f "$sif" ] || { echo "[error] missing container $sif" >&2; exit 1; }
done

if [ ! -f "$MULTIQC_SIF" ]; then
    apptainer pull "$MULTIQC_SIF" docker://quay.io/biocontainers/multiqc:1.32--pyhdfd78af_1
fi
echo "[ok] containers available"

## ---- 5. Provenance + .gitignore --------------------------------------------
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
for pattern in raw_data reference/ results/ containers/ logs/ data/ .log/ \
               '*.sif' '*.bam' '*.bai' '*.sam' '*.fastq.gz' '*.fa' '*.fai' '*.gtf' '*.ht2'; do
    grep -qxF "$pattern" "$GITIGNORE" || echo "$pattern" >> "$GITIGNORE"
done

echo "[done] Setup complete. Provenance: ${REF_DIR}/PROVENANCE.txt"