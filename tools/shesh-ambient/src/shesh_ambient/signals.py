"""Real-world signals that make proactivity offers data-aware.

Each signal is a cheap, local check. They return None when nothing notable
is found so the offer engine can skip static offers that don't apply.
Everything is injectable for tests.
"""
from __future__ import annotations

import os
import subprocess
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Signal:
    """A detected situation worth offering help with."""
    title: str
    detail: str
    action: str
    priority: int = 50


def _run(cmd: list[str], cwd: str | None = None, timeout: int = 10) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 127, ""


def find_dirty_git_repos(roots: list[Path], max_depth: int = 3) -> list[Path]:
    """Find git repos under roots that have uncommitted changes."""
    dirty: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        root = root.resolve()
        for dirpath, dirnames, _ in os.walk(root):
            depth = len(Path(dirpath).relative_to(root).parts)
            if depth > max_depth:
                dirnames[:] = []
                continue
            if ".git" in dirnames:
                rc, out = _run(["git", "status", "--porcelain"], cwd=dirpath)
                if rc == 0 and out:
                    dirty.append(Path(dirpath))
                dirnames[:] = []  # don't descend into repos
    return dirty


def git_signal(roots: list[Path]) -> Signal | None:
    repos = find_dirty_git_repos(roots)
    if not repos:
        return None
    names = ", ".join(r.name for r in repos[:3])
    more = f" (+{len(repos) - 3} more)" if len(repos) > 3 else ""
    return Signal(
        title="Commit your work?",
        detail=f"Uncommitted changes in {names}{more}.",
        action="git-status",
        priority=60 + min(len(repos), 5) * 5,
    )


def backup_age_signal(
    state_file: Path,
    warn_after_hours: float = 48.0,
) -> Signal | None:
    """Offer to back up if the last successful backup is older than threshold."""
    if not state_file.exists():
        return None
    try:
        import json
        data = json.loads(state_file.read_text())
        last = float(data.get("last_run", 0))
        if data.get("last_status") != "ok" or last == 0:
            return None
        age_h = (time.time() - last) / 3600
        if age_h >= warn_after_hours:
            return Signal(
                title="Run a backup?",
                detail=f"Last backup was {age_h:.0f} hours ago.",
                action="backup",
                priority=35,
            )
    except Exception:
        return None
    return None


def inbox_signal(inbox: Path, threshold: int = 10) -> Signal | None:
    """Offer to organize a Downloads/Inbox folder if it has many files."""
    if not inbox.exists():
        return None
    files = [p for p in inbox.iterdir() if p.is_file() and not p.name.startswith(".")]
    if len(files) >= threshold:
        return Signal(
            title="Organize your Inbox?",
            detail=f"{len(files)} files waiting in {inbox.name}.",
            action="organize-inbox",
            priority=45,
        )
    return None


def collect_signals(
    git_roots: list[Path] | None = None,
    backup_state: Path | None = None,
    inbox: Path | None = None,
    *,
    git_signal_fn: Callable = git_signal,
    backup_signal_fn: Callable = backup_age_signal,
    inbox_signal_fn: Callable = inbox_signal,
) -> list[Signal]:
    """Gather all live signals; used to override/boost static offers."""
    out: list[Signal] = []
    if git_roots:
        s = git_signal_fn(git_roots)
        if s:
            out.append(s)
    if backup_state:
        s = backup_signal_fn(backup_state)
        if s:
            out.append(s)
    if inbox:
        s = inbox_signal_fn(inbox)
        if s:
            out.append(s)
    return out
