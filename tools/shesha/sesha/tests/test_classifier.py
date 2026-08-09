"""Offline tests for smart-organizer classifier (deterministic rules only)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

CLASSIFIER = (
    Path(__file__).resolve().parents[2]
    / "smart-organizer" / "classifier.py"
)


def load_classifier():
    spec = importlib.util.spec_from_file_location("classifier", CLASSIFIER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


def test_pdf_goes_to_reference(monkeypatch, tmp_path):
    mod = load_classifier()
    monkeypatch.setattr(mod, "HOME", tmp_path, raising=False)
    monkeypatch.setenv("SHESHA_NO_LLM", "1")
    result = mod.decide(str(tmp_path / "report.pdf"))
    assert result["dest"].endswith("Documents/Reference")
    assert result["method"] == "rule"
    assert result["conf"] >= 0.8


def test_invoice_name_routes_to_finance(monkeypatch, tmp_path):
    mod = load_classifier()
    monkeypatch.setattr(mod, "HOME", tmp_path, raising=False)
    monkeypatch.setenv("SHESHA_NO_LLM", "1")
    result = mod.decide(str(tmp_path / "invoice_2026_08.pdf"))
    assert result["dest"].endswith("Documents/Personal/Finance")


def test_screenshot_routes_to_screenshots(monkeypatch, tmp_path):
    mod = load_classifier()
    monkeypatch.setattr(mod, "HOME", tmp_path, raising=False)
    monkeypatch.setenv("SHESHA_NO_LLM", "1")
    result = mod.decide(str(tmp_path / "Screenshot from 2026-08-09.png"))
    assert result["dest"].endswith("Media/Screenshots")


def test_gguf_routes_to_ai_models(monkeypatch, tmp_path):
    mod = load_classifier()
    monkeypatch.setattr(mod, "HOME", tmp_path, raising=False)
    monkeypatch.setenv("SHESHA_NO_LLM", "1")
    result = mod.decide(str(tmp_path / "phi4-mini-q4.gguf"))
    assert result["dest"].endswith("AI/Models")


def test_unknown_file_does_not_raise_and_stays_under_home(monkeypatch, tmp_path):
    mod = load_classifier()
    monkeypatch.setattr(mod, "HOME", tmp_path, raising=False)
    monkeypatch.setenv("SHESHA_NO_LLM", "1")
    result = mod.decide(str(tmp_path / "weird.xyz123"))
    assert result["dest"].startswith(str(tmp_path))
    assert result["conf"] <= 0.3  # low confidence -> should ask before moving
