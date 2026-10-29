# RUNA H3 — reproducible extensions, CUDA 12.8, models downloaded at Pod boot.
FROM runpod/comfyui:1.4.0-comfyuiv0.35.0-cuda12.8

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The official image copies /opt/comfyui-baked to /workspace on first boot.
# Bake nodes there, so ComfyUI sees them on its very first process launch.
RUN set -eux; \
    base=/opt/comfyui-baked/custom_nodes; \
    mkdir -p "$base"; \
    clone_pin() { name="$1"; repo="$2"; commit="$3"; git clone -q "$repo" "$base/$name"; git -C "$base/$name" checkout -q --detach "$commit"; }; \
    clone_pin ComfyUI-H3-Motion-Context-MultiRef https://github.com/seitanism/ComfyUI-H3-Motion-Context-MultiRef.git 361624fb406b63eb6694442eac6c895fc1533a70; \
    clone_pin H3-Optimizations https://github.com/Zironic/H3-Optimizations.git c6bc3cfc58c18c3a6220aeea09116e1eebd91669; \
    clone_pin comfyui-workflow-encrypt https://github.com/jtydhr88/ComfyUI-Workflow-Encrypt.git 5ec45fdac73d8bd6d732af76bbe81c94413b3e36; \
    clone_pin ComfyUI-VideoHelperSuite https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git 4d907bee61e92c2e65af3bd6383a4e4d356126d1; \
    git clone -q https://github.com/nicolab28/ComfyUI-ClipProj.git "$base/comfyui-clipproj"; \
    python3 -m pip install --no-cache-dir cryptography opencv-python imageio-ffmpeg

# Store the sanitized workflow in ComfyUI's saved-workflow directory.
# It contains no RUNA prompts or personal input filenames.
COPY RUNA_H3.workflow.json.gz.b64 /opt/runa-h3/workflow.json.gz.b64
RUN mkdir -p /opt/comfyui-baked/user/default/workflows \
    && base64 -d /opt/runa-h3/workflow.json.gz.b64 | gzip -dc > /opt/comfyui-baked/user/default/workflows/RUNA_H3.json

COPY bootstrap.sh /opt/runa-h3/bootstrap.sh
RUN chmod 755 /opt/runa-h3/bootstrap.sh

# Override the base image ENTRYPOINT so model downloads run BEFORE /start.sh.
# bootstrap.sh invokes /start.sh once downloads complete.
ENTRYPOINT ["/opt/runa-h3/bootstrap.sh"]
