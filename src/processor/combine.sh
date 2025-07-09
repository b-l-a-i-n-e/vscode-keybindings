#!/bin/bash

# Script to merge multiple JSON files
# Supports both array and object merging

set -e

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] file1.json file2.json [...] [output.json]

Merge multiple JSON files together.

OPTIONS:
    -h, --help          Show this help message
    -t, --type TYPE     Merge type: 'array', 'object', or 'auto' (default: auto)
    -d, --deep          Deep merge for objects (default: shallow)
    -u, --unique        For arrays, keep only unique values
    -p, --pretty        Pretty print output
    -o, --output FILE   Specify output file (alternative to last argument)
    -i, --in-place      Modify first file in-place
    -k, --keep-order    Preserve order when merging arrays
    -r, --recursive     Recursively find JSON files in directories
    -v, --verbose       Show progress information
    -c, --check         Check for conflicts without merging
    -s, --sort          Sort arrays after merging
    --stdin             Read one file from stdin (use - as filename)

EXAMPLES:
    # Merge all JSON files in current directory
    $0 *.json -o merged.json

    # Merge specific files
    $0 file1.json file2.json file3.json

    # Deep merge multiple config files
    $0 -t object -d -p config/*.json -o final-config.json

    # Merge arrays from multiple files with unique values
    $0 -t array -u -s data1.json data2.json data3.json

    # Check for conflicts in keybinding files
    $0 -c -t array keybindings/*.json

    # Merge files from stdin
    cat file1.json | $0 --stdin - file2.json file3.json

    # Recursively find and merge all JSON files
    $0 -r -t array ./configs/ -o all-configs.json

EOF
    exit 1
}

# Default values
MERGE_TYPE="auto"
DEEP_MERGE=false
UNIQUE_ONLY=false
PRETTY_PRINT=false
OUTPUT_FILE=""
IN_PLACE=false
KEEP_ORDER=false
RECURSIVE=false
VERBOSE=false
CHECK_ONLY=false
SORT_ARRAYS=false
USE_STDIN=false

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -t|--type)
            MERGE_TYPE="$2"
            shift 2
            ;;
        -d|--deep)
            DEEP_MERGE=true
            shift
            ;;
        -u|--unique)
            UNIQUE_ONLY=true
            shift
            ;;
        -p|--pretty)
            PRETTY_PRINT=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -i|--in-place)
            IN_PLACE=true
            shift
            ;;
        -k|--keep-order)
            KEEP_ORDER=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -s|--sort)
            SORT_ARRAYS=true
            shift
            ;;
        --stdin)
            USE_STDIN=true
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

# Collect input files
INPUT_FILES=()
LAST_ARG=""

# Process remaining arguments
while [[ $# -gt 0 ]]; do
    if [[ $# -eq 1 ]] && [[ -z "$OUTPUT_FILE" ]] && [[ ! -f "$1" ]] && [[ ! -d "$1" ]] && [[ "$1" != "-" ]]; then
        # Last argument might be output file
        OUTPUT_FILE="$1"
    else
        if [[ -d "$1" ]] && [[ "$RECURSIVE" = true ]]; then
            # Find JSON files recursively in directory
            while IFS= read -r -d '' file; do
                INPUT_FILES+=("$file")
            done < <(find "$1" -name "*.json" -type f -print0 | sort -z)
        else
            INPUT_FILES+=("$1")
        fi
    fi
    shift
done

# Check if we have at least 2 files to merge
if [ ${#INPUT_FILES[@]} -lt 2 ] && [ "$USE_STDIN" = false ]; then
    echo "Error: Need at least two JSON files to merge"
    usage
fi

# Verbose logging function
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1" >&2
    fi
}

# Check if files exist (skip - for stdin)
for file in "${INPUT_FILES[@]}"; do
    if [ "$file" != "-" ] && [ ! -f "$file" ]; then
        echo "Error: File '$file' not found"
        exit 1
    fi
done

# Function to read JSON from file or stdin
read_json() {
    local file="$1"
    if [ "$file" = "-" ]; then
        cat
    else
        cat "$file"
    fi
}

# Function to detect JSON type
detect_json_type() {
    local file="$1"
    local json_content
    json_content=$(read_json "$file")
    
    if echo "$json_content" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "array"
    elif echo "$json_content" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo "object"
    else
        echo "unknown"
    fi
}

# Auto-detect merge type if needed
if [ "$MERGE_TYPE" = "auto" ]; then
    log "Auto-detecting JSON type..."
    FIRST_TYPE=$(detect_json_type "${INPUT_FILES[0]}")
    MERGE_TYPE="$FIRST_TYPE"
    
    # Check if all files have the same type
    for file in "${INPUT_FILES[@]}"; do
        TYPE=$(detect_json_type "$file")
        if [ "$TYPE" != "$FIRST_TYPE" ]; then
            echo "Error: Files have different JSON types"
            echo "  ${INPUT_FILES[0]}: $FIRST_TYPE"
            echo "  $file: $TYPE"
            echo "Use -t option to force a merge type"
            exit 1
        fi
    done
    log "Detected type: $MERGE_TYPE"
fi

# Prepare jq options
JQ_OPTS=""
if [ "$PRETTY_PRINT" = true ]; then
    JQ_OPTS="--indent 4"
fi

# Function to check for conflicts (for keybindings)
check_conflicts() {
    local merge_type="$1"
    shift
    local files=("$@")
    
    if [ "$merge_type" = "array" ]; then
        # Check for duplicate keys in keybinding-style arrays
        local has_conflicts=false
        
        # Collect all entries and check for duplicate keys
        local conflicts=$(
            for file in "${files[@]}"; do
                read_json "$file"
            done | jq -s '
                flatten |
                group_by(.key // empty) |
                map(select(length > 1)) |
                map({
                    key: .[0].key,
                    count: length,
                    commands: map(.command) | unique
                })
            '
        )
        
        if [ "$(echo "$conflicts" | jq 'length')" -gt 0 ]; then
            echo "Conflicts found:"
            echo "$conflicts" | jq -r '.[] | "  Key: \(.key) appears \(.count) times with commands: \(.commands | join(", "))"'
            return 1
        else
            echo "No conflicts found"
            return 0
        fi
    else
        echo "Conflict checking is only supported for array type"
        return 0
    fi
}

# Function to merge arrays
merge_arrays() {
    local files=("$@")
    local jq_filter="flatten"
    
    if [ "$UNIQUE_ONLY" = true ]; then
        if [ "$KEEP_ORDER" = true ]; then
            # Keep order while removing duplicates
            jq_filter='flatten | unique_by(.)'
        else
            # Simple unique
            jq_filter='flatten | unique'
        fi
    fi
    
    if [ "$SORT_ARRAYS" = true ]; then
        jq_filter="$jq_filter | sort"
    fi
    
    log "Merging ${#files[@]} array files..."
    
    # Read all files and merge
    for file in "${files[@]}"; do
        read_json "$file"
    done | jq -s $JQ_OPTS "$jq_filter"
}

# Function to merge objects
merge_objects() {
    local files=("$@")
    
    log "Merging ${#files[@]} object files..."
    
    if [ "$DEEP_MERGE" = true ]; then
        # Deep merge using recursive function
        for file in "${files[@]}"; do
            read_json "$file"
        done | jq -s $JQ_OPTS '
        def deepmerge(a; b):
            a as $a | b as $b |
            if ($a | type) == "object" and ($b | type) == "object" then
                reduce ([$a, $b] | add | keys_unsorted[]) as $key (
                    {};
                    .[$key] = if ($a | has($key)) and ($b | has($key)) then
                        deepmerge($a[$key]; $b[$key])
                    elif $b | has($key) then
                        $b[$key]
                    else
                        $a[$key]
                    end
                )
            elif ($a | type) == "array" and ($b | type) == "array" then
                $a + $b
            else
                $b
            end;
        reduce .[1:][] as $item (.[0]; deepmerge(.; $item))
        '
    else
        # Shallow merge (later files overwrite earlier)
        for file in "${files[@]}"; do
            read_json "$file"
        done | jq -s $JQ_OPTS 'reduce .[] as $item ({}; . * $item)'
    fi
}

# Show files being processed
if [ "$VERBOSE" = true ]; then
    echo "Processing ${#INPUT_FILES[@]} files:"
    for file in "${INPUT_FILES[@]}"; do
        echo "  - $file"
    done
fi

# Check only mode
if [ "$CHECK_ONLY" = true ]; then
    check_conflicts "$MERGE_TYPE" "${INPUT_FILES[@]}"
    exit $?
fi

# Perform the merge based on type
case "$MERGE_TYPE" in
    array)
        RESULT=$(merge_arrays "${INPUT_FILES[@]}")
        ;;
    object)
        RESULT=$(merge_objects "${INPUT_FILES[@]}")
        ;;
    *)
        echo "Error: Unknown merge type '$MERGE_TYPE'"
        echo "Valid types are: array, object, auto"
        exit 1
        ;;
esac

# Output the result
if [ "$IN_PLACE" = true ]; then
    echo "$RESULT" > "${INPUT_FILES[0]}"
    log "Merged result written to ${INPUT_FILES[0]}"
elif [ -n "$OUTPUT_FILE" ]; then
    echo "$RESULT" > "$OUTPUT_FILE"
    log "Merged result written to $OUTPUT_FILE"
else
    echo "$RESULT"
fi

# Show summary if verbose
if [ "$VERBOSE" = true ]; then
    case "$MERGE_TYPE" in
        array)
            COUNT=$(echo "$RESULT" | jq 'length')
            echo "Merged array contains $COUNT items" >&2
            ;;
        object)
            COUNT=$(echo "$RESULT" | jq 'keys | length')
            echo "Merged object contains $COUNT keys" >&2
            ;;
    esac
fi