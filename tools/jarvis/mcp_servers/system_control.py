#!/usr/bin/env python3
"""
tools/jarvis/mcp_servers/system_control.py
Exposes system control as MCP endpoint — Newelle 1.4.5 discovers this automatically
License: GPL-3
"""
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("System Control — MSI Sword 16 HX")

@mcp.tool()
def switch_gpu_mode(mode: str) -> str:
    """
    Switch GPU/power mode.
    mode: 'gaming' (performance + dGPU hint),
          'battery' (power-saver + iGPU),
          'balanced' (balanced + hybrid)
    """
    profiles = {
        "gaming": "performance",
        "battery": "power-saver",
        "balanced": "balanced",
    }
    if mode not in profiles:
        return f"Unknown mode '{mode}'. Use: gaming, battery, balanced"

    import subprocess
    subprocess.run(["powerprofilesctl", "set", profiles[mode]], check=True)
    return f"Switched to {mode} mode (profile: {profiles[mode]})"

@mcp.tool()
def get_system_status() -> dict:
    """Get current CPU temp, GPU usage, RAM usage, battery level"""
    import subprocess, json

    # GPU info via nvidia-smi
    try:
        gpu_out = subprocess.check_output([
            "nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ], text=True).strip().split(", ")
        gpu_info = {
            "temp_c": int(gpu_out[0]),
            "util_pct": int(gpu_out[1]),
            "vram_used_mb": int(gpu_out[2]),
            "vram_total_mb": int(gpu_out[3]),
        }
    except Exception:
        gpu_info = {"error": "nvidia-smi unavailable"}

    # CPU temp
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            cpu_temp = int(f.read().strip()) // 1000
    except Exception:
        cpu_temp = -1

    return {
        "cpu_temp_c": cpu_temp,
        "gpu": gpu_info,
    }

@mcp.tool()
def trigger_smart_organizer(directory: str = "~/Downloads") -> str:
    """Run smart-organizer on a directory. Sesha delegates clutter cleanup here."""
    import subprocess, os
    expanded = os.path.expanduser(directory)
    result = subprocess.run(
        ["smart-organizer", "--once", "--dir", expanded],
        capture_output=True, text=True
    )
    return result.stdout or result.stderr

if __name__ == "__main__":
    mcp.run(transport="stdio")   # Newelle connects via stdio MCP transport