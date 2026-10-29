# RUNA H3 — Runpod ComfyUI

Automated MiniMax H3 setup for RUNA lip-sync music videos.

## What it does

- Extends Runpod ComfyUI 0.35.0 / CUDA 12.8.
- Bakes five custom-node packages into the image (no GPU time spent cloning them).
- Downloads seven model files (about 37 GB) to the temporary Pod disk before starting ComfyUI.
- Invokes Runpod's original `/start.sh` to retain FileBrowser, SSH, and JupyterLab when enabled by the Runpod template.
- Includes a sanitized RUNA_H3.json workflow (no personal prompts or input files); does **not** include RUNA portraits, audio, personal LoRAs, or credentials.

## Build

Pushing a commit to `main` starts the GitHub Actions image build, which publishes:

`ghcr.io/mikado364578/runa-h3-runpod:cuda12.8`

**Important:** New GitHub Container Registry packages may be private by default. In GitHub → Packages → `runa-h3-runpod` → Package settings, set visibility to Public **only** if you want Runpod to pull the image without registry credentials. Source code contains no secrets.

## Runpod template (after a successful image build)

- Container image: `docker.io/mikado364578/runa-h3-runpod:cuda12.8`
- Container start command: **leave blank** (the image defines its own default)
- Container disk: 100 GB for the first test (reassess usage)
- Persistent storage: 0 GB
- HTTP ports: `8188`, `8080`, `8888`
- TCP port: `22`
- Enable **Start Jupyter notebook** in the Runpod Pod/template interface when available. The image does not disable Jupyter authentication. Runpod's `/start.sh` controls startup; if logs say `JUPYTER_PASSWORD is not set; skipping JupyterLab`, verify the template's Jupyter option and environment. The checkbox alone may not suffice for this specific base image: test port 8888 before relying on it. Do not disable authentication as a workaround; Jupyter can execute terminal commands and read your files.
- Set `FILEBROWSER_PASSWORD` via Runpod Secrets (do not use its public default).
- GPU: at least 80 GB VRAM for the tested H3 workflow.

Do **not** reset, stop or restart a temporary Pod before saving outputs: the container disk is erased.

## Known testing boundary

The extension versions and seven model filenames are based on the working source Pod. This container has **not yet been validated** with a full RUNA workflow. Before production use, confirm ComfyUI's startup logs have no failed node imports, upload your own reference images and audio, and run a short one-clip test. The custom extensions are third-party code and should be reviewed before running.

The initial GitHub Actions build incurs no Runpod GPU charges, but GitHub Actions and container-registry policies/quotas still apply.
