"""
Export the trained intent classifier to ONNX.

Run after training:
    python -X utf8 training/export_onnx.py
"""

from __future__ import annotations

import json
import os
import shutil
import time
import zipfile
from pathlib import Path

import numpy as np

print("Loading dependencies...")
import onnxruntime as ort
from onnxruntime.quantization import QuantType, quantize_dynamic
from optimum.exporters.onnx import main_export
from transformers import AutoTokenizer


ROOT_DIR = Path(__file__).resolve().parents[2]
TRAINED_MODEL_DIR = ROOT_DIR / "tools" / "training" / "menu_green_intent_model" / "best"
ONNX_OUTPUT_DIR = ROOT_DIR / "runtime" / "models" / "intent_onnx"
RUNTIME_BUNDLE_DIR = ROOT_DIR / "tools" / "training" / "dist" / "intent_onnx_runtime"
RUNTIME_BUNDLE_ZIP = ROOT_DIR / "tools" / "training" / "dist" / "intent_onnx_runtime.zip"
LABEL_CONFIG_PATH = TRAINED_MODEL_DIR / "label_config.json"


def softmax(values):
    exp_values = np.exp(values - np.max(values))
    return exp_values / exp_values.sum()


def load_label_config():
    with open(LABEL_CONFIG_PATH, "r", encoding="utf-8") as file:
        return json.load(file)


def get_label_names(label_config):
    id2label = label_config["id2label"]
    return [id2label[str(index)] for index in range(len(id2label))]


def package_runtime_bundle():
    os.makedirs(RUNTIME_BUNDLE_DIR, exist_ok=True)
    os.makedirs(RUNTIME_BUNDLE_ZIP.parent, exist_ok=True)

    required_files = [
        "model.int8.onnx" if (ONNX_OUTPUT_DIR / "model.int8.onnx").exists() else "model.onnx",
        "label_config.json",
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "special_tokens_map.json",
        "sentencepiece.bpe.model",
    ]

    for file_name in required_files:
        source = ONNX_OUTPUT_DIR / file_name
        if source.exists():
            shutil.copy2(source, RUNTIME_BUNDLE_DIR / file_name)

    instructions = (
        "Extract this folder into models/intent_onnx/\n"
        "Expected result:\n"
        "  models/intent_onnx/model.int8.onnx (or model.onnx)\n"
        "  models/intent_onnx/label_config.json\n"
        "  models/intent_onnx/tokenizer.json\n"
        "Then start the API normally.\n"
    )
    with open(RUNTIME_BUNDLE_DIR / "INSTALL.txt", "w", encoding="utf-8") as file:
        file.write(instructions)

    with zipfile.ZipFile(RUNTIME_BUNDLE_ZIP, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file_name in sorted(os.listdir(RUNTIME_BUNDLE_DIR)):
            archive.write(
                RUNTIME_BUNDLE_DIR / file_name,
                arcname=os.path.join("intent_onnx", file_name),
            )

    print("\nRuntime bundle created.")
    print(f"  Folder: {RUNTIME_BUNDLE_DIR}")
    print(f"  Zip:    {RUNTIME_BUNDLE_ZIP}")
    for file_name in sorted(os.listdir(RUNTIME_BUNDLE_DIR)):
        size_mb = os.path.getsize(RUNTIME_BUNDLE_DIR / file_name) / (1024 * 1024)
        print(f"  {file_name:<40} {size_mb:.1f} MB")


print("\nExporting to ONNX...")
print(f"  Source: {TRAINED_MODEL_DIR}")
print(f"  Output: {ONNX_OUTPUT_DIR}")

if not TRAINED_MODEL_DIR.exists():
    raise FileNotFoundError(f"Missing trained model dir: {TRAINED_MODEL_DIR}")

os.makedirs(ONNX_OUTPUT_DIR, exist_ok=True)

main_export(
    model_name_or_path=TRAINED_MODEL_DIR.as_posix(),
    output=ONNX_OUTPUT_DIR.as_posix(),
    task="text-classification",
    optimize="O1",
    monolith=True,
)

fp32_model_path = str(ONNX_OUTPUT_DIR / "model.onnx")
int8_model_path = str(ONNX_OUTPUT_DIR / "model.int8.onnx")

print("\nTrying dynamic int8 quantization...")
quantized = False
try:
    quantize_dynamic(
        model_input=fp32_model_path,
        model_output=int8_model_path,
        weight_type=QuantType.QInt8,
    )
    quantized = True
    print("Quantized model created successfully.")
except Exception as exc:
    print(f"Quantization skipped: {exc}")

label_config = load_label_config()
label_names = get_label_names(label_config)

shutil.copyfile(LABEL_CONFIG_PATH, ONNX_OUTPUT_DIR / "label_config.json")

print("\nONNX export done.")
print(f"Files in {ONNX_OUTPUT_DIR}:")
for file_name in sorted(os.listdir(ONNX_OUTPUT_DIR)):
    size_mb = os.path.getsize(ONNX_OUTPUT_DIR / file_name) / (1024 * 1024)
    print(f"  {file_name:<40} {size_mb:.1f} MB")


def build_session():
    model_file = int8_model_path if quantized and os.path.exists(int8_model_path) else fp32_model_path
    tokenizer = AutoTokenizer.from_pretrained(ONNX_OUTPUT_DIR.as_posix(), use_fast=False)
    session = ort.InferenceSession(model_file, providers=["CPUExecutionProvider"])
    return tokenizer, session, model_file


print("\nVerifying ONNX model...")
tokenizer, session, active_model = build_session()
print(f"  Active model: {os.path.basename(active_model)}")


def predict(text: str):
    inputs = tokenizer(
        text,
        max_length=label_config.get("max_length", 96),
        padding="max_length",
        truncation=True,
        return_token_type_ids=True,
        return_tensors="np",
    )

    feed = {
        "input_ids": inputs["input_ids"].astype(np.int64),
        "attention_mask": inputs["attention_mask"].astype(np.int64),
    }
    if "token_type_ids" in inputs and any(node.name == "token_type_ids" for node in session.get_inputs()):
        feed["token_type_ids"] = inputs["token_type_ids"].astype(np.int64)

    outputs = session.run(None, feed)
    logits = outputs[0][0]
    probabilities = softmax(logits)
    prediction_id = int(np.argmax(probabilities))
    return {
        "label": label_names[prediction_id],
        "label_id": prediction_id,
        "score": float(probabilities[prediction_id]),
        "all_probs": {name: float(value) for name, value in zip(label_names, probabilities)},
    }


test_cases = [
    ("Tìm món ăn với cà chua", "recipe_search"),
    ("Tính BMR cho tôi", "nutrition_calc"),
    ("Nguyên liệu nào sắp hết hạn?", "inventory_check"),
    ("Lên thực đơn 7 ngày giảm cân", "meal_plan"),
    ("https://cookpad.com/vn/recipe/1", "web_browsing"),
    ("Phở bò bao nhiêu calo?", "calorie_lookup"),
    ("Ăn gì tốt cho tim mạch?", "general"),
    ("Thời tiết hôm nay thế nào?", "unknown"),
]

print(f"\n{'Text':<45} {'Expected':<20} {'Predicted':<20} {'Score':<8} {'OK?'}")
print("-" * 100)
correct = 0
for text, expected in test_cases:
    result = predict(text)
    matched = result["label"] == expected
    correct += int(matched)
    marker = "OK" if matched else "MISS"
    print(f"{text:<45} {expected:<20} {result['label']:<20} {result['score']:.3f}   {marker}")

print(f"\nAccuracy: {correct}/{len(test_cases)} ({correct / len(test_cases) * 100:.0f}%)")


print("\nLatency benchmark (100 calls):")
benchmark_text = "Tìm công thức nấu phở bò ngon"
timings = []
for _ in range(100):
    start = time.perf_counter()
    predict(benchmark_text)
    timings.append((time.perf_counter() - start) * 1000)

average = np.mean(timings)
percentile_95 = np.percentile(timings, 95)
print(f"  Average:  {average:.1f} ms")
print(f"  P95:      {percentile_95:.1f} ms")
print("  Compare:  Gemini API usually ~500-2000ms")

print("\nONNX export complete.")
print(f"Model location: {ONNX_OUTPUT_DIR}")
package_runtime_bundle()
