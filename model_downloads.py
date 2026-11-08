#!/usr/bin/env python3
"""Download the pinned RUNA H3 and official music-video models concurrently."""
import concurrent.futures
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path("/workspace/runpod-slim/ComfyUI/models")
JOBS = [
    ("H3 diffusion", "Comfy-Org/MiniMax-H3", "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors", ROOT),
    ("H3 video VAE", "Comfy-Org/MiniMax-H3", "vae/minimax_h3_video_vae_fp16.safetensors", ROOT),
    ("H3 audio VAE", "Comfy-Org/MiniMax-H3", "vae/minimax_h3_audio_vae_fp32.safetensors", ROOT),
    ("Qwen3-VL encoder", "Comfy-Org/Qwen3-VL", "text_encoders/qwen3vl_4b_fp8_scaled.safetensors", ROOT),
    ("Ref2VA LoRA", "ethanfel/MiniMax-H3-Pruned-Ref2VA-Delta-LoRAs-Experimental", "minimax_h3_pruned_bf16__apply_to_fl2va__toward_ref2va__rank512.safetensors", ROOT / "loras"),
    ("H3 turbo LoRA", "lightx2v/Minimax-h3-Turbo", "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", ROOT / "loras"),
    ("ClipProj", "NicoLab28/ClipProj-MiniMax-H3", "mmh3-4b-ClipProj-v3.1.safetensors", ROOT / "clip_projections"),
    ("Official Qwen3-VL 32B", "Comfy-Org/MiniMax-H3", "text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors", ROOT),
    ("Official H3 video VAE INT8", "Kijai/MiniMax-H3-experimental", "minimax_h3_video_vae_int8_convrot.safetensors", ROOT / "vae"),
]
MAX_WORKERS = 3
ATTEMPTS = 3


def download(job):
    name, repo, filename, directory = job
    directory.mkdir(parents=True, exist_ok=True)
    expected = directory / filename
    for attempt in range(1, ATTEMPTS + 1):
        process = subprocess.run(
            ["hf", "download", repo, filename, "--local-dir", str(directory)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            errors="replace", check=False,
        )
        if process.returncode == 0 and expected.is_file() and expected.stat().st_size > 0:
            return name, expected.stat().st_size
        print(f"[RUNA H3] WARNING {name}: attempt {attempt}/{ATTEMPTS} failed (exit={process.returncode})", flush=True)
        # Avoid printing download tool output: URLs or credentials may be included.
        if attempt < ATTEMPTS:
            time.sleep(min(10 * attempt, 30))
    raise RuntimeError(f"{name}: failed after {ATTEMPTS} attempts")


def main():
    print(f"[RUNA H3] Downloading {len(JOBS)} models, {MAX_WORKERS} parallel workers; retry on network errors.", flush=True)
    started = time.monotonic()
    completed = 0
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(download, job): job[0] for job in JOBS}
        pending = set(futures)
        while pending:
            done, pending = concurrent.futures.wait(pending, timeout=15, return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                try:
                    name, size = future.result()
                    completed += 1
                    print(f"[RUNA H3] OK {name} ({size / 1e9:.2f} GB) — {completed}/{len(JOBS)}", flush=True)
                except Exception as exc:
                    failures.append(str(exc))
                    print(f"[RUNA H3] ERROR: {exc}", flush=True)
            if pending:
                print(f"[RUNA H3] Download status: {completed}/{len(JOBS)} completed, {len(pending)} remaining, elapsed {int(time.monotonic()-started)}s.", flush=True)
    if failures:
        print("[RUNA H3] ERROR: downloads incomplete; ComfyUI will NOT be marked ready.", flush=True)
        return 1
    print(f"[RUNA H3] All 7 models verified in {int(time.monotonic()-started)}s.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
