# ONNX Training Pipeline (Project Mới)

## Mục tiêu
Train intent classifier và export ONNX trực tiếp cho runtime mới.

## Vị trí output
- Trained HF model: `tools/training/menu_green_intent_model/best`
- ONNX runtime model: `runtime/models/intent_onnx`
- Bundle zip: `tools/training/dist/intent_onnx_runtime.zip`

## Chạy theo thứ tự
```powershell
cd D:\EXE\RAG_AI_MenuGreen

# 1) Tạo/cập nhật dataset
python -X utf8 tools\training\generate_dataset.py --target-total 300000

# Muốn dataset lớn hơn nữa:
# python -X utf8 tools\training\generate_dataset.py --target-total 1000000

# 2) Train classifier
python -X utf8 tools\training\train_intent_classifier.py --batch-size 16 --epochs 12 --grad-accumulation-steps 4

# Nếu muốn train lâu hơn:
# python -X utf8 tools\training\train_intent_classifier.py --batch-size 16 --epochs 20 --grad-accumulation-steps 8

# 3) Export ONNX + verify + package
python -X utf8 tools\training\export_onnx.py
```

## Lưu ý
- Nên dùng Python 3.11.x cho stack training/export ONNX ổn định hơn.
- Nếu bạn đã có model ONNX sẵn từ project cũ, có thể bỏ qua bước train/export và chỉ cần copy vào `runtime/models/intent_onnx`.

## Environment Split (recommended)
- Runtime app: Python `3.13` + `runtime/requirements-runtime.txt`
- Training/ONNX export: Python `3.11` + lock file `tools/training/requirements-export-311.lock.txt`

Bootstrap export env:
```powershell
cd D:\EXE\RAG_AI_MenuGreen
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\training\setup_export_env_311.ps1
```

Run export using 3.11 env:
```powershell
cd D:\EXE\RAG_AI_MenuGreen
.\.venv311\Scripts\Activate.ps1
python -X utf8 tools\training\export_onnx.py
```
