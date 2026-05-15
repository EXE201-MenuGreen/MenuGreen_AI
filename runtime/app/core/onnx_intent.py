from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer


class OnnxIntentClassifier:
    def __init__(self, model_dir: Path):
        self.model_dir = model_dir
        self.model_path = self._resolve_model_path(model_dir)
        self.label_cfg = self._load_labels(model_dir / "label_config.json")
        self.tokenizer = AutoTokenizer.from_pretrained(str(model_dir))
        self.session = ort.InferenceSession(str(self.model_path), providers=["CPUExecutionProvider"])
        self.input_names = {i.name for i in self.session.get_inputs()}

    @staticmethod
    def _resolve_model_path(model_dir: Path) -> Path:
        int8_path = model_dir / "model.int8.onnx"
        fp32_path = model_dir / "model.onnx"
        if int8_path.exists():
            return int8_path
        if fp32_path.exists():
            return fp32_path
        raise FileNotFoundError("Missing ONNX model file")

    @staticmethod
    def _load_labels(path: Path) -> dict:
        if not path.exists():
            raise FileNotFoundError("Missing label_config.json")
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)

    def predict(self, text: str) -> tuple[str, float]:
        max_length = self.label_cfg.get("max_length", 96)
        inputs = self.tokenizer(
            text,
            max_length=max_length,
            padding="max_length",
            truncation=True,
            return_tensors="np",
            return_token_type_ids=True,
        )
        feed = {
            "input_ids": inputs["input_ids"].astype(np.int64),
            "attention_mask": inputs["attention_mask"].astype(np.int64),
        }
        if "token_type_ids" in inputs and "token_type_ids" in self.input_names:
            feed["token_type_ids"] = inputs["token_type_ids"].astype(np.int64)

        logits = self.session.run(None, feed)[0][0]
        probs = np.exp(logits - np.max(logits))
        probs = probs / probs.sum()
        idx = int(np.argmax(probs))

        id2label = self.label_cfg["id2label"]
        label = id2label[str(idx)]
        score = float(probs[idx])
        return label, score
