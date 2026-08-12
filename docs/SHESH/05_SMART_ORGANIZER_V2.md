# 05 — Smart-Organizer v2

> Goal: a **hands-off** file organizer that reacts within a minute of a file landing in
> Downloads/Desktop/Inbox, classifies it with deterministic rules first and a small local LLM for
> ambiguous cases, **never deletes anything you didn't approve**, and can undo every move. It is the
> first tool Shesh can drive by voice.

---

## 1. Architecture

```
 ┌─────────────────────────┐   JSON lines (stdout)   ┌──────────────────────┐
 │ sm-watcher (Rust/notify)│ ───────────────────────▶│ classifier.py (Py)    │
 │ inotify, debounce 30s   │                         │ rules → LLM → vision  │
 └─────────────────────────┘                         └──────────┬───────────┘
   watches: Downloads, Desk, Documents/Inbox, Media/Screenshots  │ decision JSON
                                                                 ▼
                                              ┌──────────────────────────────┐
                                              │ smart-organizer.sh (apply)   │
                                              │ safety → trash/undo → move   │
                                              │ → notify → audit log → MCP   │
                                              └──────────────────────────────┘
```

- **Rust watcher** is tiny (~3 MB), zero Python startup, exact event semantics.
- **Python classifier** uses deterministic rules (instant, private, no model) for ~90% of files;
  only calls Ollama (`phi4-mini`) for unknown extensions/content, and `moondream2` for images.
- **Bash apply layer** is the only thing that touches the filesystem, so safety lives in one place.
- Everything writes to one **audit/undo log** (SQLite + JSONL under `~/.local/share/smart-organizer/`).

---

## 2. The Rust watcher (`tools/smart-organizer/watcher-rs/`)

### `Cargo.toml`
```toml
[package]
name = "sm-watcher"
version = "0.2.0"
edition = "2021"
license = "GPL-3.0-only"

[dependencies]
notify = "6"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_repr = "0.1"
crossbeam-channel = "0.5"

[profile.release]
opt-level = 3
lto = true
strip = true
```

### `src/main.rs`
```rust
use notify::{Event, EventKind, RecursiveMode, Result, Watcher};
use serde::Serialize;
use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::mpsc;
use std::time::{Duration, Instant};

#[derive(Serialize)]
struct FileEvent {
    path: String,
    size: u64,
}

fn watch_dirs() -> Vec<PathBuf> {
    let home = std::env::var("HOME").unwrap_or_default();
    let h = PathBuf::from(home);
    vec![
        h.join("Downloads"),
        h.join("Desk"),
        h.join("Documents/Inbox"),
        h.join("Media/Screenshots"),
    ]
}

fn main() -> Result<()> {
    let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
    let mut w = notify::recommended_watcher(tx)?;
    for d in watch_dirs() {
        if d.exists() {
            let _ = w.watch(&d, RecursiveMode::NonRecursive);
            eprintln!("watching {}", d.display());
        }
    }

    // Debounce: collect unique new-file paths for 30s, then emit.
    let mut pending: HashSet<PathBuf> = HashSet::new();
    let mut last = Instant::now() - Duration::from_secs(60);
    loop {
        match rx.recv_timeout(Duration::from_secs(1)) {
            Ok(Ok(ev)) if matches!(ev.kind, EventKind::Create(_) | EventKind::Modify(_)) => {
                for p in ev.paths {
                    if p.is_file() { pending.insert(p); }
                }
                last = Instant::now();
            }
            _ => {}
        }
        if !pending.is_empty() && last.elapsed() > Duration::from_secs(30) {
            for p in pending.drain() {
                let size = std::fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
                if size == 0 { continue; }
                let ev = FileEvent { path: p.to_string_lossy().into(), size };
                println!("{}", serde_json::to_string(&ev).unwrap());
            }
        }
    }
}
```
Build with `cargo build --release`; install `target/release/sm-watcher` to `~/.local/bin`.

---

## 3. The Python classifier (`tools/smart-organizer/classifier.py`)

```python
#!/usr/bin/env python3
"""Smart-organizer classifier. Reads FileEvent JSON from stdin, writes decisions to stdout."""
import sys, os, re, json, mimetypes, pathlib, urllib.request

HOME = pathlib.Path.home()
OLLAMA = "http://localhost:11434/api/generate"

# Deterministic, extension-based destinations (relative to HOME). No LLM needed.
EXT_MAP = {
    # docs
    ".pdf": "Documents/Reference", ".doc": "Documents", ".docx": "Documents",
    ".xls": "Documents", ".xlsx": "Documents", ".csv": "Documents",
    ".ppt": "Documents", ".pptx": "Documents", ".odt": "Documents", ".epub": "Documents/Reference",
    # media
    ".mp4": "Media/Videos", ".mkv": "Media/Videos", ".mov": "Media/Videos", ".webm": "Media/Videos",
    ".mp3": "Media/Music", ".flac": "Media/Music", ".wav": "Media/Music", ".ogg": "Media/Music",
    ".jpg": "Media/Images", ".jpeg": "Media/Images", ".png": "Media/Images",
    ".gif": "Media/Images", ".webp": "Media/Images", ".heic": "Media/Images", ".svg": "Media/Design",
    ".raw": "Media/Images", ".psd": "Media/Design", ".xcf": "Media/Design", ".blend": "Media/Design",
    # code
    ".py": "Projects/labs", ".rs": "Projects/labs", ".js": "Projects/labs", ".ts": "Projects/labs",
    ".sh": "Projects/labs", ".go": "Projects/labs",
    # archives / installers
    ".zip": "Downloads/Archives", ".tar": "Downloads/Archives", ".gz": "Downloads/Archives",
    ".bz2": "Downloads/Archives", ".xz": "Downloads/Archives", ".zst": "Downloads/Archives",
    ".7z": "Downloads/Archives", ".rar": "Downloads/Archives",
    ".AppImage": "Downloads/Installers", ".deb": "Downloads/Installers", ".rpm": "Downloads/Installers",
    ".pkg.tar.zst": "Downloads/Installers", ".iso": "Downloads/Archives",
    # ai
    ".gguf": "AI/Models", ".safetensors": "AI/Models", ".pt": "AI/Models", ".onnx": "AI/Models",
    ".jsonl": "AI/Datasets", ".parquet": "AI/Datasets",
}
NAME_PATTERNS = [
    (re.compile(r"(?i)invoice|receipt|bill|statement"), "Documents/Personal/Finance"),
    (re.compile(r"(?i)resume|cv\b|curriculum"), "Documents/Personal"),
    (re.compile(r"(?i)screenshot|screen.?shot|Screenshot from"), "Media/Screenshots"),
    (re.compile(r"(?i)wallpaper|wallhaven"), "Media/Wallpapers"),
    (re.compile(r"(?i)^(IMG|VID|DSC)[_-]"), "Media/Camera"),
    (re.compile(r"(?i)setup|installer"), "Downloads/Installers"),
]

def decide(path: str) -> dict:
    p = pathlib.Path(path)
    name = p.name
    # name patterns first (highest signal)
    for rx, dest in NAME_PATTERNS:
        if rx.search(name):
            return {"src": path, "dest": str(HOME / dest), "method": "rule", "conf": 0.95}
    # double extension (.tar.gz, .pkg.tar.zst) then single
    ext = "".join(p.suffixes[-2:]).lower() or p.suffix.lower()
    if ext in EXT_MAP:
        return {"src": path, "dest": str(HOME / EXT_MAP[ext]), "method": "rule", "conf": 0.85}
    if p.suffix.lower() in EXT_MAP:
        return {"src": path, "dest": str(HOME / EXT_MAP[p.suffix.lower()]), "method": "rule", "conf": 0.8}
    # image with unknown ext → vision
    mime, _ = mimetypes.guess_type(str(p))
    if mime and mime.startswith("image/"):
        return _vision(p)
    # fallback: ask the LLM (only for genuinely unknown files)
    return _llm(p, mime)

def _llm(p, mime):
    prompt = (f"Classify this file into ONE of these destination folders relative to home: "
              f"Documents/Reference, Documents/Personal/Finance, Media/Images, Media/Videos, "
              f"Media/Music, Downloads/Installers, Downloads/Archives, Projects/labs, AI/Models, "
              f"AI/Datasets, Documents/Inbox.\nFile: {p.name}\nMIME: {mime}\nSizeMB: "
              f"{p.stat().st_size/1e6:.1f}\nReply JSON: {{\"dest\":\"<relative>\",\"conf\":0.0-1.0}}")
    try:
        req = urllib.request.Request(OLLAMA, data=json.dumps({
            "model": "phi4-mini", "prompt": prompt, "stream": False, "format": "json",
        }).encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(json.loads(r.read())["response"])
        dest = str(HOME / data["dest"])
        return {"src": str(p), "dest": dest, "method": "llm", "conf": float(data.get("conf", 0.4))}
    except Exception as e:
        return {"src": str(p), "dest": str(HOME / "Documents/Inbox"), "method": "fallback", "conf": 0.2, "err": str(e)}

def _vision(p):
    # moondream2 is optional; if Ollama/vision unavailable, route to Images.
    return {"src": str(p), "dest": str(HOME / "Media/Images"), "method": "mime", "conf": 0.6}

if __name__ == "__main__":
    for line in sys.stdin:
        try:
            ev = json.loads(line)
            print(json.dumps(decide(ev["path"])), flush=True)
        except Exception as e:
            print(json.dumps({"err": str(e)}), file=sys.stderr, flush=True)
```

> Keep the LLM call **optional and timeout-bounded** so the organizer never stalls when Ollama is
> busy/off. Rules cover almost everything; the LLM is a tiebreaker.

---

## 4. The apply layer (Bash) — the only mover

`smart-organizer.sh apply` reads decisions from stdin and:
1. Runs `is_protected` (centralized, deduped patterns) — skip if protected.
2. If `conf < 0.7` → `notify-send` with **Move / Leave / Always** actions (via `notify-send -A`),
   don't move until the user picks.
3. Creates the destination, handles name collisions (`name (1).ext`).
4. Records the move in `~/.local/share/smart-organizer/undo/YYYYMMDD.jsonl`:
   `{"ts":..,"from":..,"to":..,"method":..}` and inserts a row in `history.db`.
5. Uses **`gio trash`** for any deletes/cleanups (never `rm` on user files).
6. Emits a Quickshell notification (`notify-send -a SmartOrganizer ...`) and a signal Shesh can read.

Canonical, deduplicated safety patterns (`tools/smart-organizer/lib/safety.sh`):
```bash
PROTECTED_FILE_PATTERNS=(
  "*.key" "*.pem" "*.secret" "*.password" "*.kdbx" "*.kdb"
  "*.p12" "*.pfx" "*.wallet"
  "*credentials*" "*password*" "*passwd*" "*secret*" "*token*" "*api_key*" "*apikey*"
  "*id_rsa*" "*id_ed25519*" "*.env" "*.env.*"
)
```
Remove the duplicate `*credentials*` and the misplaced `*backup*` (backups aren't always protected;
that decision belongs in policy, not a glob).

---

## 5. Rules file (user-editable, overrides everything)

`~/.config/smart-organizer/rules.toml`:
```toml
# Higher priority = checked first
[[rule]]
name = "AI model files"
match_ext = ".gguf"
dest = "~/AI/Models"
priority = 100

[[rule]]
name = "Code screenshots"
match_pattern = "(?i)^(Screenshot|code)"
match_ext = ".png"
dest = "~/Media/Screenshots/Code"
priority = 95

[[rule]]
name = "Torrents"
match_ext = ".torrent"
dest = "~/Downloads/Torrents"
priority = 80
```
The classifier loads these **before** EXT_MAP/LLM so your rules always win, and "Always do this"
notifications append new rules here.

---

## 6. systemd units (canonical, no here-docs)

`tools/smart-organizer/units/smart-organizer-watch.service`:
```ini
[Unit]
Description=Smart Organizer real-time watcher
Documentation=https://github.com/gaganjainse/shesh-desktop
After=graphical-session.target ollama.service
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/bash -c '%h/.local/bin/sm-watcher | %h/.local/bin/smart-organizer apply'
Restart=on-failure
RestartSec=10
TimeoutStartSec=15
TimeoutStopSec=10
CPUQuota=8%
MemoryMax=384M
IOSchedulingClass=idle

[Install]
WantedBy=graphical-session.target
```
`smart-organizer-daily.timer` runs a full sweep at 03:00 on Sundays (uses the same classifier in a
`--once --all` mode). The watch service and timer are **the only two units**; delete the three
conflicting variants currently in the repo.

---

## 7. MCP surface for Shesh

`tools/shesh/mcp_servers/smart_organizer.py` (FastMCP stdio) exposes:
- `organize(path="~/Downloads", dry_run=False)` — trigger a sweep.
- `last_moves(n=10)` — recent activity from `history.db`.
- `undo_last()` — reverse the most recent batch (reads undo JSONL, moves files back).
- `pause(minutes=60)` / `resume()` — stop the watcher (e.g., while downloading a big torrent).

This makes "Hey Shesh, organize my downloads and undo the last thing" work by voice.

---

## 8. Safety guarantees (write these into the README and tests)

1. **Never crosses a protected path** (`projects`, `.ssh`, `.config`, `Vaults`, `Documents/Job`).
2. **Never `rm` user data** — only moves; cleanups use `gio trash`.
3. **Every move is reversible** via the undo log.
4. **Low confidence asks first** (notification action); high confidence acts and tells you.
5. **Dry-run is the default on first run** for a week (configurable), so you build trust.
6. **No network calls except local Ollama** — no cloud, no telemetry.
7. **Idempotent** — re-running doesn't duplicate or move already-organized files.

## 9. Tests

- Unit: `classifier.py` against a fixture set of 100 real-ish filenames (assert destinations).
- Safety: a test that every protected path is refused.
- Integration (container/tmp HOME): drop files in a fake `Downloads`, run the pipeline, assert moves
  and undo round-trips.
- Property: for any input, output path is always under `$HOME` and never a protected prefix.
