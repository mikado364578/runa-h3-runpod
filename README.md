# RUNA H3 — Runpod ComfyUI

Automated MiniMax H3 setup for RUNA lip-sync music videos.

## What it does

- Extends Runpod ComfyUI 0.35.0 / CUDA 12.8.
- Bakes five custom-node packages into the image (no GPU time spent cloning them).
- Downloads seven model files (about 37 GB) to the temporary Pod disk with three parallel workers, up to three attempts per file and a concise status summary.
- Opens authenticated JupyterLab on port 8888 during downloads. When all models are ready, the early Jupyter process stops briefly and Runpod's original `/start.sh` restarts JupyterLab and launches ComfyUI, SSH and FileBrowser. If no `JUPYTER_PASSWORD` is supplied, a secure per-Pod token is generated automatically.
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
- JupyterLab is enabled automatically by `bootstrap.sh` without a manually configured password: the script generates a random authentication token saved at `/workspace/.runa-jupyter-token` (permissions `600`) and supplies it as `JUPYTER_PASSWORD` to the base image's `/start.sh`. To retrieve the token from the Runpod Web Terminal: `cat /workspace/.runa-jupyter-token`. Enter that token in JupyterLab at port `8888` when asked. **Never publish the token or the Jupyter URL.** If `JUPYTER_PASSWORD` is explicitly supplied, it takes precedence; the token file won't be generated. Keep `JUPYTER_DISABLE_AUTH` unset.
- Set `FILEBROWSER_PASSWORD` via Runpod Secrets (do not use its public default).
- GPU: at least 80 GB VRAM for the tested H3 workflow.
- The Jupyter connection may briefly interrupt once at the handoff to the official Runpod startup; refresh the browser if needed. Download progress shows completed files, not unreliable byte percentages.
- `model_downloads.py` reports failures but never logs Hugging Face credentials. A failed download prevents announcing ComfyUI as ready.

Do **not** reset, stop or restart a temporary Pod before saving outputs: the container disk is erased.

## Known testing boundary

The extension versions and seven model filenames are based on the working source Pod. This container has **not yet been validated** with a full RUNA workflow. Before production use, confirm ComfyUI's startup logs have no failed node imports, upload your own reference images and audio, and run a short one-clip test. The custom extensions are third-party code and should be reviewed before running.

The initial GitHub Actions build incurs no Runpod GPU charges, but GitHub Actions and container-registry policies/quotas still apply.
