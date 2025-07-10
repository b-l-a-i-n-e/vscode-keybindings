# vscode keybindings

A collection of Makefile commands and shell scripts for validating and managing JSON files, with special support for keybinding configuration files.

## Prerequisites

- `jq` - Command-line JSON processor (required)
- `make` - GNU Make
- `bash` - Bash shell
- `python3` - Python 3.x (optional, for Python-based validation)

### Installation

**macOS:**
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq make
```

**Other systems:**
Visit https://stedolan.github.io/jq/download/

## Quick Start

```bash
# Validate all JSON files in current directory
make validate

# Check a specific file for duplicates
make check-file FILE=keybindings.json

# Show statistics for a file
make stats FILE=keybindings.json
```

## Available Commands

### Basic Validation

| Command | Description |
|---------|-------------|
| `make` or `make all` | Validate syntax and check for duplicates in all JSON files |
| `make validate` | Check JSON syntax for all files |
| `make check-file FILE=<filename>` | Validate specific file and check for duplicates |

### Analysis

| Command | Description |
|---------|-------------|
| `make stats FILE=<filename>` | Show frequency statistics for keys and commands |
| `make show-duplicates FILE=<filename>` | Display detailed information about duplicate entries |
| `make validate-structure` | Ensure all objects have required 'key' and 'command' fields |

### Utilities

| Command | Description |
|---------|-------------|
| `make format [FILE=<filename>]` | Pretty-print JSON files with proper indentation |
| `make sort-by-key FILE=<filename>` | Sort array entries by 'key' field |
| `make sort-by-command FILE=<filename>` | Sort array entries by 'command' field |
| `make clean` | Remove temporary files |

### Alternative Validators

| Command | Description |
|---------|-------------|
| `make validate-python` | Use Python for detailed validation with better error messages |
| `make help` | Display help information |

## Examples

### 1. Basic Validation
```bash
# Validate all JSON files
make

# Output:
# === Validating JSON syntax ===
# Checking keybindings.json... ✓ Valid JSON
# === Checking for duplicates ===
# Checking keybindings.json...
#   ✓ No duplicate keys
#   ✓ No duplicate commands
# ✓ No duplicates found!
```

### 2. Finding Duplicates
```bash
# Check for duplicate keys
make check-file FILE=keybindings.json

# Output (if duplicates found):
#   Checking keys in keybindings.json...
#   ✗ Duplicate keys found:
#     - ctrl+a
#     - ctrl+c
```

### 3. Detailed Duplicate Analysis
```bash
# Show which commands are mapped to duplicate keys
make show-duplicates FILE=keybindings.json

# Output:
# === Detailed duplicate analysis for keybindings.json ===
# Duplicate keys with their commands:
#   Key: ctrl+a
#     → editor.action.selectAll
#     → editor.action.selectAllOccurrences
```

### 4. View Statistics
```bash
# See frequency of keys and commands
make stats FILE=keybindings.json

# Output:
# === Statistics for keybindings.json ===
# Keys by frequency:
#   2 ctrl+a
#   1 ctrl+c
#   1 ctrl+v
#
# Commands by frequency:
#   1 editor.action.selectAll
#   1 editor.action.clipboardCopyAction
#   1 editor.action.clipboardPasteAction
```

### 5. Format and Sort
```bash
# Pretty-print a JSON file
make format FILE=keybindings.json

# Sort keybindings by key
make sort-by-key FILE=keybindings.json

# Sort by command name
make sort-by-command FILE=keybindings.json
```

## JSON File Format

This tool expects JSON files in the following format:

```json
[
    {
        "key": "ctrl+a",
        "command": "editor.action.selectAll"
    },
    {
        "key": "ctrl+c",
        "command": "editor.action.clipboardCopyAction"
    }
]
```

Each object in the array must have:
- `key`: The keyboard shortcut
- `command`: The command to execute

## Shell Scripts

In addition to the Makefile, several shell scripts are provided:

### validate-json.sh
```bash
# Validate JSON files with duplicate checking
./validate-json.sh keybindings.json

# Validate recursively
./validate-json.sh -r ./configs/

# Verbose mode
./validate-json.sh -v keybindings.json
```

### merge-json.sh
```bash
# Merge multiple JSON files
./merge-json.sh file1.json file2.json -o merged.json

# Deep merge objects
./merge-json.sh -t object -d config1.json config2.json
```

## Troubleshooting

### Common Issues

1. **"make: Nothing to be done for 'all'"**
   - No JSON files found in current directory
   - Add `.json` files or specify files explicitly

2. **"jq: command not found"**
   - Install jq using your package manager
   - See Prerequisites section above

3. **"Makefile:118: *** missing separator"**
   - Makefiles require tabs, not spaces
   - Ensure your editor uses tabs for indentation

4. **Duplicate keys not detected**
   - Ensure your JSON file is an array of objects
   - Each object should have a "key" field

## Advanced Usage

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Validate JSON files
  run: |
    make validate
    make check-duplicates
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
make validate || exit 1
```

## Contributing

Feel free to submit issues or pull requests to improve these tools.

## License

These tools are provided as-is for public use.