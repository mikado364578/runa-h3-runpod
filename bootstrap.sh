#!/usr/bin/env bash
set -Eeuo pipefail

COMFY_DIR=/workspace/runpod-slim/ComfyUI
MODEL_DIR="$COMFY_DIR/models"
BAKED_DIR=/opt/comfyui-baked
START_SCRIPT=/start.sh
EARLY_JUPYTER_PID=""

on_error() {
  echo "[RUNA H3] ERROR at line $1: startup incomplete." >&2
}
trap 'on_error "$LINENO"' ERR

echo "============================================================"
echo "  RUNA H3  |  MiniMax Music Video  |  CUDA 12.8"
echo "============================================================"
mkdir -p /workspace/runpod-slim
if [[ ! -d "$COMFY_DIR" ]]; then
  cp -a "$BAKED_DIR" "$COMFY_DIR"
fi
mkdir -p "$MODEL_DIR"/{diffusion_models,text_encoders,vae,loras,clip_projections}
command -v hf >/dev/null || { echo "[RUNA H3] ERROR: hf CLI missing." >&2; exit 1; }
command -v jupyter >/dev/null || { echo "[RUNA H3] ERROR: JupyterLab missing." >&2; exit 1; }

# This official image starts Jupyter only with JUPYTER_PASSWORD set.
# Prefer a Runpod-configured token; otherwise generate one securely, without logging it.
if [[ -z "${JUPYTER_PASSWORD:-}" && "${JUPYTER_DISABLE_AUTH:-false}" != "true" ]]; then
  TOKEN_FILE=/workspace/.runa-jupyter-token
  umask 077
  if [[ ! -s "$TOKEN_FILE" ]]; then
    python3 -c 'import secrets,pathlib; pathlib.Path("/workspace/.runa-jupyter-token").write_text(secrets.token_urlsafe(32)+"\n")'
  fi
  chmod 600 "$TOKEN_FILE"
  export JUPYTER_PASSWORD
  JUPYTER_PASSWORD="$(tr -d '\r\n' < "$TOKEN_FILE")"
  [[ -n "$JUPYTER_PASSWORD" ]] || { echo "[RUNA H3] ERROR: Jupyter token generation failed." >&2; exit 1; }
  echo "[RUNA H3] Jupyter: secure token generated (retrieve via cat /workspace/.runa-jupyter-token)."
else
  echo "[RUNA H3] Jupyter: using configured Runpod authentication."
fi

# Early Jupyter access while model downloads run. Stop it before /start.sh
# to avoid competing listeners on port 8888. /start.sh restarts it normally.
# Jupyter output goes into /jupyter-early.log, never to public startup logs.
echo "[RUNA H3] Starting early JupyterLab on port 8888..."
if [[ "${JUPYTER_DISABLE_AUTH:-false}" == "true" ]]; then
  JUPYTER_TOKEN=""
else
  JUPYTER_TOKEN="$JUPYTER_PASSWORD"
fi
export JUPYTER_TOKEN
nohup jupyter lab --allow-root --no-browser --port=8888 --ip=0.0.0.0 \
  --FileContentsManager.delete_to_trash=False \
  --FileContentsManager.preferred_dir=/workspace \
  --ServerApp.root_dir=/workspace \
  --IdentityProvider.token="$JUPYTER_TOKEN" \
  --ServerApp.allow_origin='*' > /jupyter-early.log 2>&1 &
EARLY_JUPYTER_PID=$!
echo "[RUNA H3] Early Jupyter process launched (PID $EARLY_JUPYTER_PID)."

echo "[RUNA H3] Installing/checking seven model files..."
python3 /opt/runa-h3/model_downloads.py

# Do not leave the early instance running when official /start.sh starts.
echo "[RUNA H3] Models ready. Handing services to official Runpod startup..."
if [[ -n "$EARLY_JUPYTER_PID" ]] && kill -0 "$EARLY_JUPYTER_PID" 2>/dev/null; then
  kill "$EARLY_JUPYTER_PID" 2>/dev/null || true
  for attempt in {1..20}; do
    if ! kill -0 "$EARLY_JUPYTER_PID" 2>/dev/null; then break; fi
    sleep 0.25
  done
  wait "$EARLY_JUPYTER_PID" 2>/dev/null || true
fi
# Confirm the early service really released the port before /start.sh.
if python3 -c 'import socket; s=socket.socket(); code=s.connect_ex(("127.0.0.1",8888)); s.close(); raise SystemExit(0 if code else 1)'; then
  echo "[RUNA H3] Jupyter port cleared for official restart."
else
  echo "[RUNA H3] WARNING: Jupyter port may still be in use; official startup will log any conflict."
fi

echo "============================================================"
echo "  RUNA H3 — model download summary"
echo "  Models      7/7 verified"
echo "  Workflow    $COMFY_DIR/user/default/workflows/RUNA_H3.json"
echo "  Jupyter     port 8888 (authentication enabled unless explicitly disabled)"
echo "  ComfyUI     port 8188 (starting now)"
echo "  FileBrowser port 8080 (starting now)"
echo "============================================================"
exec "$START_SCRIPT"
