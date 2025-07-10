#!/bin/bash

# JSON validation script with duplicate key checking
# Validates JSON syntax and checks for duplicate "key" values in arrays

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] file1.json [file2.json ...]

Validate JSON files and check for duplicate keys.

OPTIONS:
    -h, --help      Show this help message
    -q, --quiet     Only show errors (no success messages)
    -v, --verbose   Show detailed information
    -r, --recursive Find and validate JSON files recursively
    -d, --duplicates-only   Only check for duplicates (skip syntax check)

EXAMPLES:
    $0 keybindings.json
    $0 *.json
    $0 -r ./configs/
    $0 -v keybindings.json

EOF
    exit 0
}

# Default options
QUIET=false
VERBOSE=false
RECURSIVE=false
DUPLICATES_ONLY=false

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
        -d|--duplicates-only)
            DUPLICATES_ONLY=true
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

# Function to check for duplicate keys
check_duplicate_keys() {
    local file="$1"
    local duplicates
    
    # Check if file is an array
    if ! jq -e 'type == "array"' "$file" >/dev/null 2>&1; then
        if [ "$VERBOSE" = true ]; then
            echo "  Note: File is not an array, skipping duplicate check"
        fi
        return 0
    fi
    
    # Find duplicate keys
    duplicates=$(jq -r '
        map(.key // empty) | 
        group_by(.) | 
        map(select(length > 1)) | 
        map({key: .[0], count: length})
    ' "$file" 2>/dev/null)
    
    if [ "$duplicates" != "[]" ] && [ -n "$duplicates" ]; then
        echo -e "${YELLOW}  Duplicate keys found:${NC}"
        echo "$duplicates" | jq -r '.[] | "    - \"\(.key)\" appears \(.count) times"'
        
        if [ "$VERBOSE" = true ]; then
            # Show which entries have the duplicate keys
            echo "$duplicates" | jq -r '.[].key' | while read -r dup_key; do
                echo -e "${YELLOW}  Entries with key \"$dup_key\":${NC}"
                jq -r --arg key "$dup_key" '
                    to_entries | 
                    map(select(.value.key == $key)) | 
                    .[] | 
                    "    [\(.key)]: command = \"\(.value.command)\""
                ' "$file"
            done
        fi
        
        return 1
    fi
    
    return 0
}

# Validate each file
for file in "${FILES[@]}"; do
    ((total++))
    errors_found=false
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ $file: File not found${NC}"
        ((invalid++))
        continue
    fi
    
    # Check JSON syntax (unless duplicates-only mode)
    if [ "$DUPLICATES_ONLY" != true ]; then
        if ! jq empty "$file" 2>/dev/null; then
            echo -e "${RED}✗ $file: Invalid JSON syntax${NC}"
            errors_found=true
            
            # Show error details if verbose
            if [ "$VERBOSE" = true ]; then
                echo -e "${RED}  Error details:${NC}"
                jq . "$file" 2>&1 | sed 's/^/    /'
            fi
        elif [ "$QUIET" != true ]; then
            echo -e "${GREEN}✓ $file: Valid JSON${NC}"
        fi
    fi
    
    # Check for duplicate keys
    if ! check_duplicate_keys "$file"; then
        if [ "$errors_found" = false ]; then
            echo -e "${RED}✗ $file: Contains duplicate keys${NC}"
        fi
        errors_found=true
    elif [ "$DUPLICATES_ONLY" = true ] && [ "$QUIET" != true ]; then
        echo -e "${GREEN}✓ $file: No duplicate keys${NC}"
    fi
    
    # Update counters
    if [ "$errors_found" = true ]; then
        ((invalid++))
    else
        ((valid++))
    fi
done

# Summary
echo
if [ $invalid -eq 0 ]; then
    echo -e "${GREEN}All $total files passed validation${NC}"
    exit 0
else
    echo -e "${RED}Found issues in $invalid out of $total files${NC}"
    exit 1
fi