# Makefile for concatenating multiple JSON array files

# Configuration
INPUT_DIR := src/keybindings
OUTPUT_DIR := output
OUTPUT_FILE := $(OUTPUT_DIR)/keybindings.json

# Find all JSON files in the input directory
JSON_FILES := $(wildcard $(INPUT_DIR)/*.json)

# Default target
.PHONY: all
all: $(OUTPUT_FILE)

.PHONY: validate
validate: $(OUTPUT_FILE)
	@echo "Validating JSON file..."
	src/processor/validate.sh $(OUTPUT_FILE)

.PHONY: test
test: ${JSON_FILES}
	src/processor/validate.sh $(JSON_FILES)

.PHONE: clean
clean:
	rm -rf $(OUTPUT_DIR)

# Create output directory if it doesn't exist
$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Main target: concatenate all JSON arrays
$(OUTPUT_FILE): $(JSON_FILES) | $(OUTPUT_DIR) $(TEMP_DIR)
	src/processor/combine.sh ${JSON_FILES} ${OUTPUT_FILE}