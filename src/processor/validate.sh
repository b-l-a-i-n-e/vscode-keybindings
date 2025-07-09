#!/bin/bash

# Simple JSON validation script
# Only checks if files contain valid JSON syntax

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] file1.json [file2.json ...]

Validate JSON files for correct syntax.

OPTIONS:
    -h, --help      Show this help message
    -q, --quiet     Only show errors (no success messages)
    -v, --verbose   Show detailed error messages
    -r, --recursive Find and validate JSON files recursively

EXAMPLES:
    $0 config.json
    $0 *.json
    $0 -r ./configs/
    $0 -q data/*.json

EOF
    exit 0
}

# Default options
QUIET=false
VERBOSE=false
RECURSIVE=false

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Collect files to validate
FILES=()

if [ "$RECURSIVE" = true ]; then
    # Find all .json files recursively
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            while IFS= read -r -d '' file; do
                FILES+=("$file")
            done < <(find "$arg" -name "*.json" -type f -print0)
        else
            FILES+=("$arg")
        fi
    done
else
    FILES=("$@")
fi

# Check if any files specified
if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files specified"
    usage
fi

# Counters
total=0
valid=0
invalid=0

# Validate each file
for file in "${FILES[@]}"; do
    ((total++))
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ $file: File not found${NC}"
        ((invalid++))
        continue
    fi
    
    # Check if valid JSON
    if jq empty "$file" 2>/dev/null; then
        if [ "$QUIET" != true ]; then
            echo -e "${GREEN}✓ $file${NC}"
        fi
        ((valid++))
    else
        echo -e "${RED}✗ $file${NC}"
        ((invalid++))
        
        # Show error details if verbose
        if [ "$VERBOSE" = true ]; then
            echo -e "${RED}  Error details:${NC}"
            jq . "$file" 2>&1 | sed 's/^/    /'
        fi
    fi
done

# Summary
echo
if [ $invalid -eq 0 ]; then
    echo -e "${GREEN}All $total files are valid JSON${NC}"
    exit 0
else
    echo -e "${RED}Found $invalid invalid files out of $total${NC}"
    exit 1
fi