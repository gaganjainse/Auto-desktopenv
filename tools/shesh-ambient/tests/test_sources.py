"""Offline tests for data-aware proactivity sources (roadmap P1)."""

from __future__ import annotations

import random
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from shesh_ambient.proactivity import (  # noqa: E402
    Offer,
    ProactivityState,
    pick_offer,
    should_offer,
)
from shesh_ambient.sources import (  # noqa: E402
    Facts,
    backup_age_days,
    detail_for,
    downloads_new_count,
    gather_facts,
    git_uncommitted_count,
)


def fake_runner(stdout="", returncode=0):
    def _run(cmd, **kw):
        return subprocess.CompletedProcess(cmd, returncode, stdout, "")

    return _run


def test_git_uncommitted_count_counts_lines():
    r = fake_runner(" M file1.py\n?? new.py\n")
    assert git_uncommitted_count("/repo", r) == 2


def test_git_uncommitted_count_clean_repo():
    r = fake_runner("", 0)
    assert git_uncommitted_count("/repo", r) == 0


def test_git_uncommitted_count_offline_fallback():
    r = fake_runner("", 127)  # git not available
    assert git_uncommitted_count("/repo", r) is None


def test_backup_age_days(tmp_path):
    marker = tmp_path / "last_backup"
    marker.write_text("ok")
    old = time.time() - 2 * 86400
    import os

    os.utime(marker, (old, old))
    age = backup_age_days(str(tmp_path))
    assert age is not None and 1.5 < age < 2.5


def test_backup_age_none_when_never_backed_up(tmp_path):
    assert backup_age_days(str(tmp_path)) is None


def test_downloads_new_count(tmp_path):
    old = time.time() - 7200
    fresh = time.time()
    f1 = tmp_path / "a.pdf"
    f2 = tmp_path / "b.zip"
    f3 = tmp_path / "just-downloaded.tmp"
    f1.write_text("x")
    f2.write_text("x")
    f3.write_text("x")
    import os

    os.utime(f1, (old, old))
    os.utime(f2, (old, old))
    os.utime(f3, (fresh, fresh))  # too fresh -> not counted
    assert downloads_new_count(str(tmp_path), min_age_s=3600) == 2


def test_gather_facts_all_fallible(tmp_path):
    facts = gather_facts(
        repo=str(tmp_path),  # not a git repo -> runner fails -> None
        state_dir=str(tmp_path / "missing"),
        downloads_dir=str(tmp_path / "missing"),
        runner=fake_runner("", 127),
    )
    assert facts.uncommitted is None
    assert facts.backup_age_days is None
    assert facts.downloads_new is None


def test_detail_for_real_facts():
    facts = Facts(uncommitted=3, backup_age_days=2.0, downloads_new=5, disk_free_gb=42.5)
    assert "3 uncommitted changes" in detail_for("git-status", facts)
    assert "2.0 days" in detail_for("backup", facts)
    assert "5 new files" in detail_for("organize-downloads", facts)
    assert "42.5 GiB" in detail_for("focus-mode", facts)


def test_detail_for_none_when_fact_missing():
    assert detail_for("git-status", Facts()) is None
    assert detail_for("unknown-action", Facts(uncommitted=1)) is None


def test_pick_offer_enriches_detail_with_facts():
    ctx = type("C", (), {"natural_pause": True})()
    state = ProactivityState(offered_today=set())
    import random

    rng = random.Random(1)
    candidates = [Offer("Commit your work?", "static", "git-status", priority=100)]
    offer = pick_offer(ctx, state, candidates=candidates, rng=rng, facts=Facts(uncommitted=7))
    assert offer is not None
    assert "7 uncommitted changes" in offer.detail
    assert offer.detail != "static"


def test_pick_offer_keeps_static_when_no_facts():
    ctx = type("C", (), {"natural_pause": True})()
    state = ProactivityState(offered_today=set())
    candidates = [Offer("Commit your work?", "static", "git-status", priority=100)]
    offer = pick_offer(ctx, state, candidates=candidates, rng=random.Random(1))
    assert offer is not None and offer.detail == "static"


def test_should_offer_respects_pause_and_cooldown():
    ctx = type("C", (), {"natural_pause": False})()
    assert not should_offer(ctx, ProactivityState(), now=1000.0)
    ctx = type("C", (), {"natural_pause": True})()
    state = ProactivityState(last_offer_ts=999.0, min_interval_s=1800)
    assert not should_offer(ctx, state, now=1000.0)  # cooldown
    state = ProactivityState(last_offer_ts=0.0)
    assert should_offer(ctx, state, now=10000.0)  # past cooldown
