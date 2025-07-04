#!/bin/bash

# Usage: ./conda2sif.sh <env_file.yml> <def_output_dir> <sif_output_dir> <image_name>

set -e

# Parse arguments using getopts for user-friendly CLI
print_usage() {
    echo "Usage: $0 -e <env_file.yml> -d <def_output_dir> -s <sif_output_dir> -n <image_name>"
    echo ""
    echo "  -e    Path to the conda environment YAML file (required)"
    echo "  -d    Output directory for Singularity definition file (required)"
    echo "  -s    Output directory for SIF image (required)"
    echo "  -n    Name for the image (required)"
    exit 1
}

while getopts ":e:d:s:n:h" opt; do
    case $opt in
        e) ENV_FILE="$OPTARG" ;;
        d) DEF_DIR="$OPTARG" ;;
        s) SIF_DIR="$OPTARG" ;;
        n) IMAGE_NAME="$OPTARG" ;;
        h) print_usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; print_usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; print_usage ;;
    esac
done

# Check required arguments
if [ -z "$ENV_FILE" ] || [ -z "$DEF_DIR" ] || [ -z "$SIF_DIR" ] || [ -z "$IMAGE_NAME" ]; then
    print_usage
fi


DEF_FILE="${DEF_DIR}/${IMAGE_NAME}.def"
SIF_FILE="${SIF_DIR}/${IMAGE_NAME}.sif"

# Check if env_file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' does not exist."
    exit 2
fi

# Create output directories if they do not exist
mkdir -p "$DEF_DIR"
mkdir -p "$SIF_DIR"

# Generate Singularity definition file
cat > "$DEF_FILE" <<EOF
Bootstrap: docker
From: mambaorg/micromamba

%files
    $ENV_FILE /environment.yml

%post
    micromamba env create -f /environment.yml
    micromamba clean -afy
    micromamba shell init -s bash --root-prefix /opt/micromamba

%environment
    source /opt/micromamba/etc/profile.d/mamba.sh
    micromamba activate \`head -1 /environment.yml | cut -d' ' -f2\`

%runscript
    /bin/bash
EOF

echo "Definition file created at $DEF_FILE"

# Build the SIF image
singularity build --fakeroot "$SIF_FILE" "$DEF_FILE"

echo "SIF image created at $SIF_FILE"