# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ComfyUI-Docker-CUDA-preloaded is a Docker solution for running [ComfyUI](https://github.com/comfyanonymous/ComfyUI) with CUDA GPU support and automatic model/extension downloads. It handles the full lifecycle: building a CUDA-enabled image, downloading hundreds of GB of AI models on first run, and installing 70+ community extensions.

## Common Commands

```bash
# Build the image
docker compose build

# Start (first time or after Dockerfile changes)
docker compose up -d --build

# Regular start/stop
docker compose up -d
docker compose down

# Quick start wrapper
./run.sh

# Validate all model download URLs in models.conf
./check_urls.sh

# Reset Python venv and extension state (force full reinstall on next start)
./force_clean_venv.sh
# Equivalent manual steps:
docker compose down
docker volume rm comfyui_venv
rm -Rf custom_nodes/.last_commits
```

ComfyUI web interface is available at `http://localhost:8188` after container start.

## Architecture

### Initialization Flow

On every container start, `entrypoint.sh` runs `init_models.sh` and `init_extensions.sh` before launching ComfyUI. Both scripts are idempotent — they skip already-downloaded models and already-installed extensions.

- **`init_scripts/config.sh`** — Shared utilities: colored logging, disk space checks, `download_file` with retry/exponential backoff, `clone_or_update_repo` with git LFS support.
- **`init_scripts/init_models.sh`** — Reads `models.conf`, parses INI sections (e.g. `[CHECKPOINTS]`, `[VAE]`), downloads missing files via wget/curl into the corresponding `models/<category>/` subdirectory.
- **`init_scripts/init_extensions.sh`** — Reads `extensions.conf` (one git URL per line), clones or updates each repo, installs Python deps, tracks installed commit hashes in `custom_nodes/.last_commits/` to skip unchanged extensions.
- **`entrypoint.sh`** — Orchestrates the above, then runs ComfyUI.

### Configuration Files

- **`models.conf`** — INI-style. Each section header is a model category matching a `models/` subdirectory. Each line is `filename = url`. Comment out lines to skip downloads and save disk space (~250 GB total if all enabled).
- **`extensions.conf`** — One ComfyUI extension git URL per line. Comment out to skip.

### Docker Volumes

Four host directories are bind-mounted (created alongside the repo):

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `./models` | `/comfyui/models` | AI model files |
| `./custom_nodes` | `/comfyui/custom_nodes` | Extensions |
| `./output` | `/comfyui/output` | Generated images/video |
| `./input` | `/comfyui/input` | Input images |

A named volume `comfyui_venv` persists the Python virtual environment across rebuilds.

### Dockerfile Structure

Two-stage conceptual build (single `FROM` but with distinct phases):
1. System deps: CUDA 12.8.1 + Ubuntu 24.04, Python 3.12, ffmpeg, fonts, cuDNN
2. bitsandbytes built from source targeting CUDA 12.4 (required for correct binary compilation)
3. PyTorch 2.6.0 + xformers + GPU inference libraries (onnxruntime-gpu, etc.)
4. ComfyUI cloned at last stable tag

The CUDA library path environment (`LD_LIBRARY_PATH`, `CUDA_HOME`) is set in both the Dockerfile and `docker-compose.yml` to ensure GPU libraries are found at runtime.

## Key Conventions

- **Shell scripts use `source init_scripts/config.sh`** to access shared logging and download functions — always keep that import when adding new init scripts.
- **Model categories in `models.conf` must match subdirectory names** that ComfyUI expects under `models/` (e.g. `checkpoints`, `vae`, `loras`).
- **Extension tracking** uses per-repo files in `custom_nodes/.last_commits/<repo-name>` containing the last installed commit hash. Delete these files to force reinstall of specific extensions.
- The `check_urls.sh` script is the canonical way to validate `models.conf` after editing URLs — run it before committing URL changes.
