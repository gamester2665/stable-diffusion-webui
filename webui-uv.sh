#!/usr/bin/env bash
# Stable Diffusion WebUI launcher using uv (https://github.com/astral-sh/uv)
# Run: ./webui-uv.sh [launch.py args...]

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

# Source webui-user.sh for COMMANDLINE_ARGS etc.
if [[ -f "$SCRIPT_DIR/webui-user.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/webui-user.sh"
fi

export COMMANDLINE_ARGS="${COMMANDLINE_ARGS:---xformers --disable-safe-unpickle --api}"
export VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/.venv}"
export UV_PYTHON="${UV_PYTHON:-3.10}"
export SD_WEBUI_RESTART=tmp/restart
export ERROR_REPORTING=FALSE

mkdir -p tmp

# Check uv is available
if ! command -v uv &>/dev/null; then
    echo "uv is not installed. Install with: pip install uv"
    echo "Or: https://github.com/astral-sh/uv#installation"
    exit 1
fi

# Windows (Git Bash, MSYS, Cygwin) uses Scripts/python.exe; Unix uses bin/python
if [[ -f "$VENV_DIR/Scripts/python.exe" ]]; then
    PYTHON="$VENV_DIR/Scripts/python.exe"
elif [[ -f "$VENV_DIR/bin/python" ]]; then
    PYTHON="$VENV_DIR/bin/python"
else
    PYTHON=""
fi

# Create venv if it doesn't exist (UV_VENV_CLEAR=1 skips "replace?" prompt)
if [[ -z "$PYTHON" ]]; then
    echo "Creating virtual environment with uv..."
    UV_VENV_CLEAR=1 uv venv "$VENV_DIR" --python "$UV_PYTHON"
    [[ $? -ne 0 ]] && UV_VENV_CLEAR=1 uv venv "$VENV_DIR"
    # Resolve path after creation
    if [[ -f "$VENV_DIR/Scripts/python.exe" ]]; then
        PYTHON="$VENV_DIR/Scripts/python.exe"
    else
        PYTHON="$VENV_DIR/bin/python"
    fi
fi

# Install dependencies with uv if requirements not met
echo "Checking dependencies..."
if ! "$PYTHON" -c "import torch, torchvision" &>/dev/null; then
    echo "Installing PyTorch with uv..."
    uv pip install --python "$PYTHON" torch==2.1.2 torchvision==0.16.2 --extra-index-url https://download.pytorch.org/whl/cu121
    [[ $? -ne 0 ]] && uv pip install --python "$PYTHON" torch==2.1.2 torchvision==0.16.2
fi

if ! "$PYTHON" -c "import gradio" &>/dev/null; then
    echo "Installing requirements..."
    uv pip install --python "$PYTHON" -r requirements_versions.txt --index-strategy unsafe-best-match
fi

if ! "$PYTHON" -c "import clip" &>/dev/null; then
    echo "Installing CLIP..."
    uv pip install --python "$PYTHON" "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"
    "$PYTHON" -c "import clip; from pathlib import Path; f=Path(clip.__file__).parent/'clip.py'; f.write_text(f.read_text().replace('from pkg_resources import packaging','import packaging'))"
fi

# Launch loop
while true; do
    echo "Launching Stable Diffusion WebUI..."
    "$PYTHON" -u launch.py --skip-install "$@"
    [[ ! -f tmp/restart ]] && break
done
