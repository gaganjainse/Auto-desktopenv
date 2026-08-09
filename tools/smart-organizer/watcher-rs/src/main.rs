//! sm-watcher — real-time, debounced inotify watcher for the smart-organizer.
//!
//! Watches a fixed set of directories (Downloads, Desk, Documents/Inbox,
//! Media/Screenshots) non-recursively, debounces events for 30s, then emits one
//! JSON line per new file on stdout:
//!
//!   {"path":"/home/gagan/Downloads/foo.pdf","size":12345}
//!
//! The Python classifier reads these lines and decides a destination.
//! License: GPL-3.0   See docs/SESHA/05_SMART_ORGANIZER_V2.md

use notify::{Event, EventKind, RecursiveMode, Watcher};
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

fn home() -> PathBuf {
    std::env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/root"))
}

fn watch_dirs() -> Vec<PathBuf> {
    let h = home();
    vec![
        h.join("Downloads"),
        h.join("Desk"),
        h.join("Documents/Inbox"),
        h.join("Media/Screenshots"),
    ]
}

fn main() -> notify::Result<()> {
    let (tx, rx) = mpsc::channel::<notify::Result<Event>>();
    let mut watcher = notify::recommended_watcher(tx)?;

    for d in &watch_dirs() {
        if d.exists() {
            if let Err(e) = watcher.watch(d, RecursiveMode::NonRecursive) {
                eprintln!("warn: cannot watch {}: {e}", d.display());
            } else {
                eprintln!("watching {}", d.display());
            }
        }
    }

    let mut pending: HashSet<PathBuf> = HashSet::new();
    let mut last = Instant::now() - Duration::from_secs(60);
    let debounce = Duration::from_secs(30);

    loop {
        match rx.recv_timeout(Duration::from_secs(1)) {
            Ok(Ok(ev)) if matches!(ev.kind, EventKind::Create(_) | EventKind::Modify(_)) => {
                for p in ev.paths {
                    if p.is_file() {
                        pending.insert(p);
                    }
                }
                last = Instant::now();
            }
            Ok(Err(e)) => eprintln!("watch error: {e}"),
            _ => {}
        }

        // Flush after the debounce window.
        if !pending.is_empty() && last.elapsed() > debounce {
            for p in pending.drain() {
                let size = std::fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
                if size == 0 {
                    continue;
                }
                let ev = FileEvent {
                    path: p.to_string_lossy().into_owned(),
                    size,
                };
                println!("{}", serde_json::to_string(&ev).unwrap());
            }
            // Flush stdout immediately so the classifier reacts promptly.
            use std::io::Write;
            let _ = std::io::stdout().flush();
        }
    }
}
