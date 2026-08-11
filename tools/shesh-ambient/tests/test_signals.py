"""Offline tests for data-aware proactivity signals."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from shesh_ambient import signals as sig  # noqa: E402


def test_inbox_signal_triggers_above_threshold(tmp_path):
    inbox = tmp_path / "Downloads"
    inbox.mkdir()
    for i in range(12):
        (inbox / f"file{i}.txt").write_text("x")
    s = sig.inbox_signal(inbox, threshold=10)
    assert s is not None
    assert "12 files" in s.detail and s.action == "organize-inbox"


def test_inbox_signal_silent_when_few(tmp_path):
    inbox = tmp_path / "Downloads"
    inbox.mkdir()
    (inbox / "a.txt").write_text("x")
    assert sig.inbox_signal(inbox) is None


def test_backup_age_signal(tmp_path):
    state = tmp_path / "state.json"
    old = time.time() - 72 * 3600  # 3 days ago
    state.write_text(json.dumps({"last_run": old, "last_status": "ok"}))
    s = sig.backup_age_signal(state, warn_after_hours=48)
    assert s is not None and s.action == "backup"


def test_backup_age_signal_ignores_recent(tmp_path):
    state = tmp_path / "state.json"
    state.write_text(json.dumps({"last_run": time.time(), "last_status": "ok"}))
    assert sig.backup_age_signal(state) is None


def test_git_signal_uses_injected_runner(tmp_path):
    repo = tmp_path / "proj"
    repo.mkdir()
    (repo / ".git").mkdir()

    def fake_runner(roots):
        return sig.Signal(title="Commit", detail="dirty", action="git-status", priority=60)

    s = sig.collect_signals(git_roots=[tmp_path], git_signal_fn=fake_runner)
    assert any(x.action == "git-status" for x in s)


def test_collect_signals_combines(tmp_path):
    inbox = tmp_path / "Inbox"
    inbox.mkdir()
    for i in range(11):
        (inbox / f"f{i}").write_text("x")
    found = sig.collect_signals(
        inbox=inbox,
        git_signal_fn=lambda r: None,
        backup_signal_fn=lambda p: None,
    )
    assert any(x.action == "organize-inbox" for x in found)
