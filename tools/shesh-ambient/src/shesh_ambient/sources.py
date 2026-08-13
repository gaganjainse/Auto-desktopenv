"""Real data sources for data-aware proactivity (roadmap P1).

Each source returns a short human detail string, or None when the fact is
unavailable (offline, no repo, no backup state) — the engine then falls back
to the static default. All sources take an injected runner so they are fully
offline-testable.
"""

from __future__ import annotations

import os
import pathlib
import subprocess
from collections.abc import Callable
from dataclasses import dataclass

Runner = Callable[[list[str]], "subprocess.CompletedProcess[str]"]


def _default_runner(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return subprocess.CompletedProcess(cmd, 127, "", "")


@dataclass(frozen=True)
class Facts:
    """Real facts gathered for the current moment. None = unknown."""

    uncommitted: int | None = None
    backup_age_days: float | None = None
    downloads_new: int | None = None
    disk_free_gb: float | None = None


def git_uncommitted_count(repo: str | None = None, runner: Runner = _default_runner) -> int | None:
    """Count uncommitted changes in a repo (or the first repo found upward)."""
    if not repo:
        return None
    p = runner(["git", "-C", repo, "status", "--porcelain"])
    if p.returncode != 0:
        return None
    return len([line for line in p.stdout.splitlines() if line.strip()])


def backup_age_days(state_dir: str | None = None, runner: Runner = _default_runner) -> float | None:
    """Age of the newest backup marker, in days. None when never backed up."""
    if not state_dir:
        return None
    marker = pathlib.Path(state_dir) / "last_backup"
    if not marker.exists():
        return None
    age = os.path.getmtime(marker)
    return max(0.0, (__import__("time").time() - age) / 86400.0)


def downloads_new_count(downloads_dir: str | None = None, min_age_s: int = 3600) -> int | None:
    """How many files landed in Downloads recently (older than min_age_s so
    in-flight downloads are not counted)."""
    if not downloads_dir:
        return None
    d = pathlib.Path(downloads_dir)
    if not d.is_dir():
        return None
    now = __import__("time").time()
    return sum(
        1
        for f in d.iterdir()
        if f.is_file() and (now - f.stat().st_mtime) > min_age_s and not f.name.startswith(".")
    )


def disk_free_gb(path: str = "/") -> float | None:
    """Free space on the given mount, in GiB."""
    try:
        st = os.statvfs(path)
        return round(st.f_bavail * st.f_frsize / (1024**3), 1)
    except OSError:
        return None


def gather_facts(
    *,
    repo: str | None = None,
    state_dir: str | None = None,
    downloads_dir: str | None = None,
    runner: Runner = _default_runner,
) -> Facts:
    """Gather all facts, each independently fallible."""
    return Facts(
        uncommitted=git_uncommitted_count(repo, runner),
        backup_age_days=backup_age_days(state_dir, runner),
        downloads_new=downloads_new_count(downloads_dir),
        disk_free_gb=disk_free_gb(),
    )


def detail_for(action: str, facts: Facts) -> str | None:
    """Map a fact to a concrete detail line for an offer, or None."""
    if action == "git-status" and facts.uncommitted is not None:
        n = facts.uncommitted
        return f"{n} uncommitted change{'s' if n != 1 else ''} in the workspace."
    if action == "backup" and facts.backup_age_days is not None:
        return f"Last backup was {facts.backup_age_days:.1f} days ago."
    if action == "organize-downloads" and facts.downloads_new is not None:
        return (
            f"{facts.downloads_new} new file{'s' if facts.downloads_new != 1 else ''} in Downloads."
        )
    if action == "focus-mode" and facts.disk_free_gb is not None:
        return f"{facts.disk_free_gb} GiB free on root."
    return None
