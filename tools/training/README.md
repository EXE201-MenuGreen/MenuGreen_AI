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
python -X utf8 tools\training\generate_dataset.py

# 2) Train classifier
python -X utf8 tools\training\train_intent_classifier.py

# 3) Export ONNX + verify + package
python -X utf8 tools\training\export_onnx.py
```

## Lưu ý
- Nên dùng Python 3.11.x cho stack training/export ONNX ổn định hơn.
- Nếu bạn đã có model ONNX sẵn từ project cũ, có thể bỏ qua bước train/export và chỉ cần copy vào `runtime/models/intent_onnx`.
