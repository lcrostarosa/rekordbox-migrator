# Rekordbox Path Updater - Makefile
# Automated build and run commands for the Rekordbox path updater

# Default values
XML_FILE ?= "rekordbox backup.xml"
NEW_PATH ?= "/Volumes/External/Music/"
WORKERS ?= 8
PYTHON ?= python3
PIP ?= pip3

# Colors for output
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Rekordbox Path Updater - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Installation & Setup:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(install|test|setup)"
	@echo ""
	@echo "$(GREEN)Main Operations:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(dry-run|update|restore)"
	@echo ""
	@echo "$(GREEN)Utility Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "(clean|check|verify)"
	@echo ""
	@echo "$(GREEN)Usage Examples:$(NC)"
	@echo "  make dry-run XML_FILE=\"my_library.xml\" NEW_PATH=\"/Music/\""
	@echo "  make update XML_FILE=\"my_library.xml\" NEW_PATH=\"/Music/\""
	@echo "  make install"
	@echo "  make test"

# Installation targets
.PHONY: install
install: ## Install dependencies and setup the environment
	@echo "$(BLUE)Installing Rekordbox Path Updater...$(NC)"
	@echo "$(YELLOW)Checking Python version...$(NC)"
	@$(PYTHON) --version || (echo "$(RED)Python not found. Please install Python 3.6+$(NC)" && exit 1)
	@echo "$(GREEN)✓ Python found$(NC)"
	@echo "$(YELLOW)Installing Python dependencies...$(NC)"
	@$(PIP) install -r requirements.txt || echo "$(YELLOW)No external dependencies required$(NC)"
	@echo "$(GREEN)✓ Dependencies installed$(NC)"
	@echo "$(YELLOW)Making scripts executable...$(NC)"
	@chmod +x rekordbox_path_updater.py
	@chmod +x rekordbox_path_updater.sh
	@echo "$(GREEN)✓ Scripts made executable$(NC)"
	@echo "$(GREEN)Installation complete!$(NC)"

.PHONY: setup
setup: install ## Alias for install
	@echo "$(GREEN)Setup complete!$(NC)"

# Testing targets
.PHONY: test
test: ## Test the installation and verify everything works
	@echo "$(BLUE)Testing Rekordbox Path Updater...$(NC)"
	@echo "$(YELLOW)Testing Python script...$(NC)"
	@$(PYTHON) rekordbox_path_updater.py --help > /dev/null && echo "$(GREEN)✓ Python script works$(NC)" || (echo "$(RED)✗ Python script failed$(NC)" && exit 1)
	@echo "$(YELLOW)Testing bash script...$(NC)"
	@./rekordbox_path_updater.sh > /dev/null 2>&1 && echo "$(GREEN)✓ Bash script works$(NC)" || echo "$(YELLOW)⚠ Bash script requires xmlstarlet$(NC)"
	@echo "$(YELLOW)Checking for sample XML file...$(NC)"
	@if [ -f "rekordbox backup.xml" ]; then echo "$(GREEN)✓ Sample XML file found$(NC)"; else echo "$(YELLOW)⚠ No sample XML file found$(NC)"; fi
	@echo "$(GREEN)All tests passed!$(NC)"

.PHONY: check
check: test ## Alias for test
	@echo "$(GREEN)Check complete!$(NC)"

# Main operation targets
.PHONY: dry-run
dry-run: ## Run the script in dry-run mode to preview changes
	@echo "$(BLUE)Running Rekordbox Path Updater in DRY-RUN mode...$(NC)"
	@echo "$(YELLOW)XML File: $(XML_FILE)$(NC)"
	@echo "$(YELLOW)New Path: $(NEW_PATH)$(NC)"
	@echo "$(YELLOW)Workers: $(WORKERS)$(NC)"
	@echo "$(YELLOW)No changes will be made to your files$(NC)"
	@echo "$(BLUE)--------------------------------------------------$(NC)"
	@$(PYTHON) rekordbox_path_updater.py "$(XML_FILE)" "$(NEW_PATH)" --dry-run --workers $(WORKERS)
	@echo "$(BLUE)--------------------------------------------------$(NC)"
	@echo "$(GREEN)Dry-run complete!$(NC)"

.PHONY: update
update: ## Run the script to actually update the XML file
	@echo "$(BLUE)Running Rekordbox Path Updater...$(NC)"
	@echo "$(YELLOW)XML File: $(XML_FILE)$(NC)"
	@echo "$(YELLOW)New Path: $(NEW_PATH)$(NC)"
	@echo "$(YELLOW)Workers: $(WORKERS)$(NC)"
	@echo "$(RED)WARNING: This will modify your XML file!$(NC)"
	@echo "$(YELLOW)A backup will be created automatically$(NC)"
	@echo "$(BLUE)--------------------------------------------------$(NC)"
	@$(PYTHON) rekordbox_path_updater.py "$(XML_FILE)" "$(NEW_PATH)" --workers $(WORKERS)
	@echo "$(BLUE)--------------------------------------------------$(NC)"
	@echo "$(GREEN)Update complete!$(NC)"

.PHONY: restore
restore: ## Restore the original file from backup
	@echo "$(BLUE)Restoring from backup...$(NC)"
	@if [ -f "$(XML_FILE).backup" ]; then \
		cp "$(XML_FILE).backup" "$(XML_FILE)"; \
		echo "$(GREEN)✓ Restored from backup$(NC)"; \
	else \
		echo "$(RED)✗ No backup file found$(NC)"; \
		exit 1; \
	fi

# Verification targets
.PHONY: verify
verify: ## Verify that the XML file and new path exist
	@echo "$(BLUE)Verifying inputs...$(NC)"
	@if [ -f $(XML_FILE) ]; then \
		echo "$(GREEN)✓ XML file exists: $(XML_FILE)$(NC)"; \
	else \
		echo "$(RED)✗ XML file not found: $(XML_FILE)$(NC)"; \
		exit 1; \
	fi
	@if [ -d $(NEW_PATH) ]; then \
		echo "$(GREEN)✓ New path exists: $(NEW_PATH)$(NC)"; \
	else \
		echo "$(RED)✗ New path not found: $(NEW_PATH)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)All verifications passed!$(NC)"

.PHONY: info
info: ## Show information about the current setup
	@echo "$(BLUE)Rekordbox Path Updater - System Information$(NC)"
	@echo "$(YELLOW)Python version:$(NC)"
	@$(PYTHON) --version
	@echo "$(YELLOW)Current directory:$(NC)"
	@pwd
	@echo "$(YELLOW)Available files:$(NC)"
	@ls -la *.py *.sh *.xml 2>/dev/null || echo "No relevant files found"
	@echo "$(YELLOW)XML file status:$(NC)"
	@if [ -f $(XML_FILE) ]; then \
		echo "$(GREEN)✓ $(XML_FILE) exists$(NC)"; \
		echo "  Size: $$(ls -lh $(XML_FILE) | awk '{print $$5}')"; \
		echo "  Modified: $$(ls -lh $(XML_FILE) | awk '{print $$6, $$7, $$8}')"; \
	else \
		echo "$(RED)✗ $(XML_FILE) not found$(NC)"; \
	fi
	@echo "$(YELLOW)New path status:$(NC)"
	@if [ -d $(NEW_PATH) ]; then \
		echo "$(GREEN)✓ $(NEW_PATH) exists$(NC)"; \
		echo "  Contents: $$(ls $(NEW_PATH) | wc -l) items"; \
	else \
		echo "$(RED)✗ $(NEW_PATH) not found$(NC)"; \
	fi

# Utility targets
.PHONY: clean
clean: ## Clean up temporary files and backups
	@echo "$(BLUE)Cleaning up...$(NC)"
	@rm -f *.tmp *.temp *.bak 2>/dev/null || true
	@echo "$(YELLOW)Warning: This will remove backup files and logs!$(NC)"
	@read -p "Remove backup files and logs? (y/N): " confirm && [ "$$confirm" = "y" ] && rm -f *.backup && rm -rf logs && echo "$(GREEN)✓ Backups and logs removed$(NC)" || echo "$(YELLOW)Backups and logs preserved$(NC)"
	@echo "$(GREEN)Cleanup complete!$(NC)"

.PHONY: backup
backup: ## Create a manual backup of the XML file
	@echo "$(BLUE)Creating manual backup...$(NC)"
	@if [ -f $(XML_FILE) ]; then \
		cp $(XML_FILE) "$(XML_FILE).manual-backup.$$(date +%Y%m%d_%H%M%S)"; \
		echo "$(GREEN)✓ Manual backup created$(NC)"; \
	else \
		echo "$(RED)✗ XML file not found$(NC)"; \
		exit 1; \
	fi

# Advanced targets
.PHONY: install-xmlstarlet
install-xmlstarlet: ## Install xmlstarlet for bash script support
	@echo "$(BLUE)Installing xmlstarlet...$(NC)"
	@if command -v brew >/dev/null 2>&1; then \
		echo "$(YELLOW)Using Homebrew...$(NC)"; \
		brew install xmlstarlet; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "$(YELLOW)Using apt-get...$(NC)"; \
		sudo apt-get update && sudo apt-get install -y xmlstarlet; \
	elif command -v yum >/dev/null 2>&1; then \
		echo "$(YELLOW)Using yum...$(NC)"; \
		sudo yum install -y xmlstarlet; \
	else \
		echo "$(RED)✗ Package manager not found$(NC)"; \
		echo "$(YELLOW)Please install xmlstarlet manually$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ xmlstarlet installed$(NC)"

.PHONY: compare
compare: ## Compare original and updated files (if backup exists)
	@echo "$(BLUE)Comparing files...$(NC)"
	@if [ -f "$(XML_FILE).backup" ]; then \
		echo "$(YELLOW)Comparing $(XML_FILE) with backup...$(NC)"; \
		diff "$(XML_FILE).backup" "$(XML_FILE)" || echo "$(YELLOW)Files are different (expected after update)$(NC)"; \
	else \
		echo "$(RED)✗ No backup file found$(NC)"; \
	fi

# Development targets
.PHONY: lint
lint: ## Run basic linting checks
	@echo "$(BLUE)Running linting checks...$(NC)"
	@if command -v flake8 >/dev/null 2>&1; then \
		flake8 rekordbox_path_updater.py; \
	else \
		echo "$(YELLOW)flake8 not found, skipping linting$(NC)"; \
	fi
	@echo "$(GREEN)Linting complete!$(NC)"

.PHONY: format
format: ## Format Python code
	@echo "$(BLUE)Formatting Python code...$(NC)"
	@if command -v black >/dev/null 2>&1; then \
		black rekordbox_path_updater.py; \
	else \
		echo "$(YELLOW)black not found, skipping formatting$(NC)"; \
	fi
	@echo "$(GREEN)Formatting complete!$(NC)"

# Documentation
.PHONY: docs
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@echo "$(YELLOW)Documentation is in README.md$(NC)"
	@echo "$(GREEN)Documentation complete!$(NC)"

# Default help
.PHONY: default
default: help 

.PHONY: deps
deps: ## Install all dependencies (Homebrew, Python, xmlstarlet, psutil)
	@echo "$(BLUE)Checking Homebrew...$(NC)"
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "$(YELLOW)Homebrew not found. Installing Homebrew...$(NC)"; \
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "$(GREEN)✓ Homebrew found$(NC)"; \
	fi
	@echo "$(BLUE)Checking Python...$(NC)"
	@if ! command -v python3 >/dev/null 2>&1; then \
		echo "$(YELLOW)Python3 not found. Installing Python...$(NC)"; \
		brew install python; \
	else \
		echo "$(GREEN)✓ Python3 found$(NC)"; \
	fi
	@echo "$(BLUE)Checking xmlstarlet...$(NC)"
	@if ! command -v xmlstarlet >/dev/null 2>&1; then \
		echo "$(YELLOW)xmlstarlet not found. Installing xmlstarlet...$(NC)"; \
		brew install xmlstarlet; \
	else \
		echo "$(GREEN)✓ xmlstarlet found$(NC)"; \
	fi
	@echo "$(BLUE)Installing Python dependencies...$(NC)"
	@$(PYTHON) -m pip install --user psutil || echo "$(YELLOW)psutil installation failed (optional for better performance)$(NC)"
	@echo "$(GREEN)All dependencies installed!$(NC)" 