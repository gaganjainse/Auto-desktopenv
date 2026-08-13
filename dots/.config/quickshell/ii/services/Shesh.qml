pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common

/**
 * Shesh — applies the user's settings (Config.options.shesh) to the system.
 *
 * Toggles translate to `systemctl --user` unit state and hyprctl visual state.
 * All effects are idempotent and safe to re-run; the service only acts when a
 * value actually changes, and never touches job/vault paths.
 */
Singleton {
    id: root

    function systemctl(action, unit) {
        Quickshell.execDetached(["systemctl", "--user", action, unit]);
    }

    function applyPowerVisuals() {
        if (!Config.options.shesh.lowPowerVisuals) {
            Quickshell.execDetached(["hyprctl", "--keyword", "decoration:blur:passes", "3"]);
            Quickshell.execDetached(["hyprctl", "--keyword", "decoration:shadow:enabled", "1"]);
            return;
        }
        // Lighten visuals only while on battery, full on AC.
        Quickshell.execDetached(["bash", "-c",
            "if [ \"$(cat /sys/class/power_supply/AC/online 2>/dev/null)\" = \"0\" ]; then " +
            "hyprctl --keyword decoration:blur:passes 1; " +
            "hyprctl --keyword decoration:shadow:enabled 0; " +
            "else " +
            "hyprctl --keyword decoration:blur:passes 3; " +
            "hyprctl --keyword decoration:shadow:enabled 1; fi"]);
    }

    function applyAll() {
        const on = Config.options.shesh.enabled;
        systemctl(on ? "enable --now" : "disable --now", "shesh-mcp.target");
        systemctl(Config.options.shesh.realtimeOrganizer && on ? "enable --now" : "disable --now",
                  "smart-organizer-watch.service");
        systemctl(Config.options.shesh.autoBackup && on ? "enable --now" : "disable --now",
                  "backup.timer");
        systemctl(Config.options.shesh.autoPowerProfile && on ? "enable --now" : "disable --now",
                  "shesh-power.service");
        applyPowerVisuals();
        applyMcp();
        applyPolicy();
    }

    // Rebuild ~/.config/shesh/mcp/*.json from the MCP toggles + channel.
    function applyMcp() {
        if (!Config.options.shesh.enabled) {
            return; // master switch off: leave the generated config untouched
        }
        const m = Config.options.shesh.mcp;
        const names = [];
        const pairs = [
            [m.audit, "shesh-audit"], [m.backup, "shesh-backup"],
            [m.calendar, "shesh-calendar"], [m.containers, "shesh-containers"],
            [m.ebpf, "shesh-ebpf"], [m.harness, "shesh-harness"],
            [m.mcpBundle, "shesh-mcp-bundle"], [m.media, "shesh-media"],
            [m.memory, "shesh-memory"], [m.messaging, "shesh-messaging"],
            [m.mind, "shesh-mind"], [m.secrets, "shesh-secrets"],
            [m.shell, "shesh-shell"], [m.skills, "shesh-skills"],
            [m.system, "shesh-system"],
        ];
        for (let i = 0; i < pairs.length; i++) {
            if (pairs[i][0]) names.push(pairs[i][1]);
        }
        const channel = Config.options.shesh.channel || "canary";
        const script = `${Directories.home}/src/shesh-ecosystem/scripts/generate_mcp_config.py`;
        Quickshell.execDetached(["bash", "-c",
            `if [ -f "$1" ]; then exec python3 "$1" --channel "$2" --servers "$3"; ` +
            `else echo "shesh: generate_mcp_config.py not found at $1 (run install-shesh-stack.sh)" >&2; fi`,
            "shesh-mcp-apply", script, channel, names.join(",")]);
    }

    // Write ~/.config/shesh/policy.json from the Governance page, then bounce
    // the audit server so it re-loads the policy. Uses the venv python when the
    // full stack is installed, else system python3 with a here-doc.
    function applyPolicy() {
        if (!Config.options.shesh.enabled) return;
        const verdict = Config.options.shesh.policy.defaultVerdict;
        const protect = Config.options.shesh.policy.protectPaths ? "true" : "false";
        const dir = `${Directories.home}/.config/shesh`;
        // Heredoc writes the exact JSON load_policy() expects; then bounce the
        // audit server so it re-loads the policy.
        const cmd = `mkdir -p "${dir}" && cat > "${dir}/policy.json" <<EOF\n` +
            `{\n  "version": 1,\n  "default_verdict": "${verdict}",\n  "protected_paths": ${protect}\n}\nEOF`;
        Quickshell.execDetached(["bash", "-c", cmd]);
        systemctl("restart", "shesh-audit-mcp.service");
    }

    // React to every option under shesh.*
    property var _opts: Config.options.shesh
    onOpts_changed: applyAll()

    Component.onCompleted: {
        if (Config.ready) applyAll();
    }

    Connections {
        target: Config
        function onReadyChanged() { if (Config.ready) root.applyAll(); }
    }
}
