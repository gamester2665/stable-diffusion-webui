@echo off
REM Stable Diffusion WebUI launcher using uv (https://github.com/astral-sh/uv)
REM Run: webui-uv.bat [launch.py args...]

if exist webui.settings.bat (
    call webui.settings.bat
)
if not defined COMMANDLINE_ARGS (set "COMMANDLINE_ARGS=--xformers --disable-safe-unpickle --api")

if not defined VENV_DIR (set "VENV_DIR=%~dp0.venv")
if not defined UV_PYTHON (set "UV_PYTHON=3.10")

set SD_WEBUI_RESTART=tmp/restart
set ERROR_REPORTING=FALSE

mkdir tmp 2>NUL

REM Check uv is available
where uv >tmp/stdout.txt 2>tmp/stderr.txt
if %ERRORLEVEL% neq 0 (
    echo uv is not installed. Install with: pip install uv
    echo Or: https://github.com/astral-sh/uv#installation
    goto :show_stderr
)

REM Create venv if it doesn't exist
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo Creating virtual environment with uv...
    uv venv "%VENV_DIR%" --python %UV_PYTHON%
    if %ERRORLEVEL% neq 0 (
        echo Failed to create venv. Trying system Python...
        uv venv "%VENV_DIR%"
    )
    if %ERRORLEVEL% neq 0 goto :show_stderr
)

set PYTHON="%VENV_DIR%\Scripts\python.exe"

REM Install dependencies with uv if requirements not met
echo Checking dependencies...
%PYTHON% -c "import torch, torchvision" 2>NUL
if %ERRORLEVEL% neq 0 (
    echo Installing PyTorch with uv...
    uv pip install --python "%VENV_DIR%\Scripts\python.exe" torch==2.1.2 torchvision==0.16.2 --extra-index-url https://download.pytorch.org/whl/cu121
    if %ERRORLEVEL% neq 0 (
        echo CUDA 12.1 failed. Trying CPU-only...
        uv pip install --python "%VENV_DIR%\Scripts\python.exe" torch==2.1.2 torchvision==0.16.2
    )
)

%PYTHON% -c "import gradio" 2>NUL
if %ERRORLEVEL% neq 0 (
    echo Installing requirements...
    uv pip install --python "%VENV_DIR%\Scripts\python.exe" -r requirements_versions.txt
)

%PYTHON% -c "import clip" 2>NUL
if %ERRORLEVEL% neq 0 (
    echo Installing CLIP...
    uv pip install --python "%VENV_DIR%\Scripts\python.exe" "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"
    REM Fix CLIP: pkg_resources.packaging removed in newer setuptools
    %PYTHON% -c "import clip; from pathlib import Path; f=Path(clip.__file__).parent/'clip.py'; f.write_text(f.read_text().replace('from pkg_resources import packaging','import packaging'))"
)
REM open_clip is provided by open-clip-torch from requirements_versions.txt

:launch
REM Run launch.py with --skip-install (we use uv for deps)
echo Launching Stable Diffusion WebUI...
%PYTHON% launch.py --skip-install %*
if EXIST tmp/restart goto :launch
pause
exit /b

:show_stderr
if exist tmp\stderr.txt type tmp\stderr.txt
pause
exit /b 1
