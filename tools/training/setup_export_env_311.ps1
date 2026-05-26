Param(
  [string]$VenvPath = ".venv311"
)

$ErrorActionPreference = "Stop"

Write-Host "== Setup Python 3.11 export env ==" -ForegroundColor Cyan

py -0p | Out-Host

Write-Host "[1/5] Create venv with Python 3.11..." -ForegroundColor Yellow
py -3.11 -m venv $VenvPath

Write-Host "[2/5] Activate venv..." -ForegroundColor Yellow
. "$VenvPath\Scripts\Activate.ps1"

Write-Host "[3/5] Upgrade pip tooling..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel

Write-Host "[4/5] Install locked export dependencies..." -ForegroundColor Yellow
python -m pip install -r "tools\training\requirements-export-311.lock.txt"

Write-Host "[5/5] Smoke check versions..." -ForegroundColor Yellow
python -c "import sys, torch, onnx, onnxruntime, transformers, optimum; print('python:', sys.version); print('torch:', torch.__version__); print('onnx:', onnx.__version__); print('onnxruntime:', onnxruntime.__version__); print('transformers:', transformers.__version__); print('optimum:', optimum.__version__)"

Write-Host "Done. Use this env for train/export only." -ForegroundColor Green
