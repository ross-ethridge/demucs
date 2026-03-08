SHELL = /bin/sh
current-dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Default options
gpu = false
mp3output = false
model = htdemucs
shifts = 1
overlap = 0.25
jobs = 1
splittrack =

.DEFAULT_GOAL := help

.PHONY:
init:
ifeq ($(gpu), true)
  docker-gpu-option = --gpus all
endif
ifeq ($(mp3output), true)
  demucs-mp3-option = --mp3
endif
ifneq ($(splittrack),)
  demucs-twostems-option = --two-stems $(splittrack)
endif

# Construct commands
docker-run-command = docker run --rm -i \
	--name=demucs \
	$(docker-gpu-option) \
	-v $(current-dir)input:/data/input \
	-v $(current-dir)output:/data/output \
	-v $(current-dir)models:/data/models \
	demucs:latest

demucs-command = "python3 -m demucs -n $(model) \
	--out /data/output \
	$(demucs-mp3-option) \
	$(demucs-twostems-option) \
	--shifts $(shifts) \
	--overlap $(overlap) \
	-j $(jobs) \
	\"/data/input/$(track)\""

.PHONY:
.SILENT:
help: ## Display available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf " \033[36m%-20s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY:
.SILENT:
run: init build ## Run demucs to split the specified track in the input folder
	@echo $(docker-run-command) $(demucs-command)
	$(docker-run-command) $(demucs-command)

.PHONY:
.SILENT:
run-interactive: init build ## Run the docker container interactively to experiment with demucs options
	$(docker-run-command) /bin/bash

.PHONY:
.SILENT:
build: ## Build the docker image which supports running demucs with CPU only or with Nvidia CUDA on a supported GPU
	docker build -t demucs:latest .

.PHONY:
.SILENT:
setup: ## First-time setup: copy env.template to .env and generate SECRET_KEY_BASE
	@cp -n env.template .env || true
	@secret=$$(docker run --rm ruby:4.0.1-slim ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"); \
	 sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$$secret|" .env
	@echo "Done. Edit .env to set POSTGRES_PASSWORD, then run: make up"

.PHONY:
.SILENT:
up: build ## Build all images and start the web app
	docker compose up --build -d --scale worker=3

.PHONY:
.SILENT:
down: ## Stop the web app
	docker compose down

.PHONY:
.SILENT:
logs: ## Tail web and worker logs
	docker compose logs -f web worker

.PHONY:
.SILENT:
logs-worker: ## Tail worker logs only
	docker compose logs -f worker
