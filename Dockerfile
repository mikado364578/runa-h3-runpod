# RUNA H3 — experimental CUDA 13.0 build. Keep stable CUDA 12.8 on main.
# Pinned upstream CUDA 13.0 image; experimental, not the stable main image.
# Revalidate custom nodes and startup compatibility with newer RunPod image.
FROM runpod/comfyui:2.2.1-rc.237-comfyuiv0.44.0-cuda13.0

# Fail the build immediately if the selected base is not running PyTorch CUDA 13.
RUN python3 -c "import torch; print('Build PyTorch:', torch.__version__, 'CUDA:', torch.version.cuda); assert torch.version.cuda is not None and torch.version.cuda.startswith('13.'), 'Expected PyTorch CUDA 13.x'"

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

# Install all three CUDA 13 workflows for side-by-side testing.
# Existing workflows from the base image are removed from the baked installation.
RUN mkdir -p /opt/comfyui-baked/user/default/workflows \
    && find /opt/comfyui-baked/user/default/workflows -maxdepth 1 -type f -name '*.json' -delete
COPY RUNA_H3_Cuda13.json /opt/comfyui-baked/user/default/workflows/RUNA_H3_Cuda13.json
COPY ["NEW - Music Video.json", "/opt/comfyui-baked/user/default/workflows/NEW - Music Video.json"]
COPY H3_ComfyUI_Official_Ref2V.json /opt/comfyui-baked/user/default/workflows/H3_ComfyUI_Official_Ref2V.json

COPY bootstrap.sh model_downloads.py /opt/runa-h3/
RUN chmod 755 /opt/runa-h3/bootstrap.sh

# Override the base image ENTRYPOINT so model downloads run BEFORE /start.sh.
# bootstrap.sh invokes /start.sh once downloads complete.
ENTRYPOINT ["/opt/runa-h3/bootstrap.sh"]
