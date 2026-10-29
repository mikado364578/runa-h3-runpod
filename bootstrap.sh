#!/usr/bin/env bash
set -Eeuo pipefail

COMFY_DIR=/workspace/runpod-slim/ComfyUI
MODEL_DIR="$COMFY_DIR/models"
BAKED_DIR=/opt/comfyui-baked
START_SCRIPT=/start.sh

on_error() {
  echo "[RUNA H3] Setup FAILED at line $1. Original ComfyUI has not been started." >&2
  echo "[RUNA H3] Inspect the download error; do not assume the Pod is ready." >&2
}
trap 'on_error "$LINENO"' ERR

echo "[RUNA H3] Preparing official ComfyUI install..."
mkdir -p /workspace/runpod-slim
if [[ ! -d "$COMFY_DIR" ]]; then
  cp -a "$BAKED_DIR" "$COMFY_DIR"
fi

mkdir -p "$MODEL_DIR"/{diffusion_models,text_encoders,vae,loras,clip_projections}
command -v hf >/dev/null || { echo '[RUNA H3] Missing hf CLI' >&2; exit 1; }

fetch_nested() {
  local repo="$1" path="$2"
  echo "[RUNA H3] $repo / $path"
  hf download "$repo" "$path" --local-dir "$MODEL_DIR"
}
fetch_flat() {
  local repo="$1" filename="$2" subdir="$3"
  echo "[RUNA H3] $repo / $filename"
  hf download "$repo" "$filename" --local-dir "$MODEL_DIR/$subdir"
}

fetch_nested Comfy-Org/MiniMax-H3 diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
fetch_nested Comfy-Org/MiniMax-H3 vae/minimax_h3_video_vae_fp16.safetensors
fetch_nested Comfy-Org/MiniMax-H3 vae/minimax_h3_audio_vae_fp32.safetensors
fetch_nested Comfy-Org/Qwen3-VL text_encoders/qwen3vl_4b_fp8_scaled.safetensors
fetch_flat ethanfel/MiniMax-H3-Pruned-Ref2VA-Delta-LoRAs-Experimental minimax_h3_pruned_bf16__apply_to_fl2va__toward_ref2va__rank512.safetensors loras
fetch_flat lightx2v/Minimax-h3-Turbo minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors loras
fetch_flat NicoLab28/ClipProj-MiniMax-H3 mmh3-4b-ClipProj-v3.1.safetensors clip_projections

# /start.sh starts JupyterLab only when JUPYTER_PASSWORD is set.
# Create a per-Pod cryptographically secure token without logging its value.
# Respect an explicit JUPYTER_PASSWORD supplied through Runpod.
if [[ -z "${JUPYTER_PASSWORD:-}" && "${JUPYTER_DISABLE_AUTH:-false}" != "true" ]]; then
  TOKEN_FILE=/workspace/.runa-jupyter-token
  umask 077
  if [[ ! -s "$TOKEN_FILE" ]]; then
    python3 -c 'import secrets, pathlib; pathlib.Path("/workspace/.runa-jupyter-token").write_text(secrets.token_urlsafe(32) + "\n")'
  fi
  chmod 600 "$TOKEN_FILE"
  export JUPYTER_PASSWORD
  JUPYTER_PASSWORD="$(tr -d '\r\n' < "$TOKEN_FILE")"
  [[ -n "$JUPYTER_PASSWORD" ]] || { echo '[RUNA H3] Jupyter token generation failed' >&2; exit 1; }
  echo "[RUNA H3] JupyterLab authentication enabled; retrieve its token with: cat /workspace/.runa-jupyter-token"
fi

echo "[RUNA H3] All seven model files are ready."
echo "[RUNA H3] Starting official Runpod services and ComfyUI..."
exec "$START_SCRIPT"
