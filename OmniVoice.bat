@echo off
setlocal

:: Define local paths for 100% portability
set "OMNIVOICE_ROOT=%~dp0"
set "UV_CACHE_DIR=%OMNIVOICE_ROOT%.uv_cache"
set "UV_PYTHON_INSTALL_DIR=%OMNIVOICE_ROOT%.uv_python"
set "HF_HOME=%OMNIVOICE_ROOT%.hf_cache"
set "XDG_CACHE_HOME=%OMNIVOICE_ROOT%.cache"
set "PYTHONPATH=%OMNIVOICE_ROOT%"
set "UV_LINK_MODE=copy"

:: Explicitly target the first NVIDIA GPU
set "CUDA_VISIBLE_DEVICES=0"

:: Ensure we are in the correct directory
cd /d "%OMNIVOICE_ROOT%"

:: Marker file to track first-run completion
set "SETUP_MARKER=%OMNIVOICE_ROOT%.venv\.setup_done"

echo.
echo ========================================================
echo   OmniVoice Portable Launcher (GPU Enhanced)
echo ========================================================
echo.

:: ---- Step 1: Check uv ----
echo [1/4] Checking for 'uv' installation...
where uv >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: 'uv' is not installed or not in PATH.
    echo Please install it from: https://github.com/astral-sh/uv
    pause
    exit /b 1
)

:: ---- Step 2: Sync deps ----
if exist "%SETUP_MARKER%" (
    echo [2/4] Dependencies already installed. Quick check...
    uv sync --all-extras >nul 2>&1
) else (
    echo [2/4] Synchronizing dependencies (CUDA 12.8^)...
    echo (First GPU sync will take time. Subsequent launches will be instant.^)
    uv sync --all-extras
    if %errorlevel% neq 0 (
        echo Error: Dependency sync failed.
        pause
        exit /b 1
    )
)

:: ---- Step 3: GPU Check (only on first run) ----
if exist "%SETUP_MARKER%" (
    echo [3/4] GPU already verified. Skipping...
) else (
    echo [3/4] Verifying GPU/CUDA Status...
    uv run python -c "import torch; available = torch.cuda.is_available(); print(f' - Detected GPU: {torch.cuda.get_device_name(0)}' if available else ' - !!! GPU NOT DETECTED !!! (Running on CPU)'); print(f' - VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB' if available else '')"
    :: Create marker after successful first setup
    echo setup_complete > "%SETUP_MARKER%"
)

:: ---- Step 4: Launch ----
:: If model is already cached, run in offline mode to avoid 429 rate-limit errors
if exist "%HF_HOME%\hub\models--k2-fsa--OmniVoice\snapshots" (
    echo [4/4] Launching OmniVoice Web UI (offline mode - model cached^)...
    set "HF_HUB_OFFLINE=1"
) else (
    echo [4/4] Launching OmniVoice Web UI (will download model from HuggingFace^)...
)

uv run omnivoice-demo

echo.
echo Application closed.
pause
