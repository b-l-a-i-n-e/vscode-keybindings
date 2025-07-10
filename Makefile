# Makefile for concatenating multiple JSON array files

# Configuration
INPUT_DIR := src/keybindings
OUTPUT_DIR := output
OUTPUT_FILE := $(OUTPUT_DIR)/keybindings.json

JSON_FILES := $(wildcard $(INPUT_DIR)/*.json)

.PHONY: all
all: test $(OUTPUT_FILE) validate

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

.PHONY: clean
clean:
	rm -rf $(OUTPUT_DIR)

.PHONY: validate
validate: $(OUTPUT_FILE)
	@echo "Validating JSON file..."
	src/processor/validate.sh $(OUTPUT_FILE)

.PHONY: test
test: ${JSON_FILES}
	src/processor/validate.sh $(JSON_FILES)

# Main target: concatenate all JSON arrays
$(OUTPUT_FILE): $(JSON_FILES) | $(OUTPUT_DIR) $(TEMP_DIR)
	src/processor/combine.sh ${JSON_FILES} ${OUTPUT_FILE}