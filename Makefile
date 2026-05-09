SHELL = /bin/sh

.DEFAULT_GOAL := help

.PHONY:
.SILENT:
help: ## Show available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf " \033[36m%-20s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY:
install: ## Install Python dependencies (run once)
	pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu126
	pip install -r requirements.txt
