#!/bin/bash

# Script to scan a directory for .mp4 files, extract track count,
# and extract audio from each track as PCM_S16LE encoded WAV files

set -e  # Exit on error

# Default directory to scan (can be overridden)
SCAN_DIR="${1:-.}"
OUTPUT_DIR="${2:-.}"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

# Check if directory exists
if [ ! -d "$SCAN_DIR" ]; then
    echo "Error: Directory '$SCAN_DIR' does not exist."
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Scanning directory: $SCAN_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Find all .mp4 files
MP4_FILES=("$SCAN_DIR"/*.mp4)

# Check if any mp4 files were found
if [ ! -e "${MP4_FILES[0]}" ]; then
    echo "No .mp4 files found in '$SCAN_DIR'"
    exit 0
fi

echo "Found $(ls -1 "$SCAN_DIR"/*.mp4 2>/dev/null | wc -l) file(s)"
echo ""

# Process each mp4 file
for mp4_file in "$SCAN_DIR"/*.mp4; do
    if [ ! -f "$mp4_file" ]; then
        continue
    fi
    
    filename=$(basename "$mp4_file")
    echo "Processing: $filename"
    
    # Get the base name without extension for output files
    base_name="${filename%.mp4}"
    
    # Extract track count using ffmpeg
    track_count=$(ffmpeg -i "$mp4_file" 2>&1 | grep -oP 'Stream #[0-9]+:\K[0-9]+' | sort -u | tail -1)
    
    if [ -z "$track_count" ]; then
        echo "  Warning: Could not determine number of audio tracks. Skipping."
        continue
    fi
    
    echo "  Found $track_count audio track(s)"
    
    # Extract each audio track
    for ((i=0; i<track_count; i++)); do
        output_file="$OUTPUT_DIR/${base_name}_T${i}.wav"
        
        echo "  Extracting track $i to: $output_file"
        
        # Extract audio stream with PCM_S16LE encoding
        ffmpeg -y -i "$mp4_file" \
            -map "0:a:$i" \
            -c:a pcm_s16le \
            "$output_file" 2>&1 | grep -E "(Extracting|Output|Error)"
        
        if [ $? -eq 0 ]; then
            echo "    Successfully extracted track $i"
        else
            echo "    Error extracting track $i"
        fi
    done
    
    echo ""
done

echo "Done!"
