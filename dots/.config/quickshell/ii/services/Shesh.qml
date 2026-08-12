pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common

/**
 * Shesh — applies the user's settings (Config.options.sesha) to the system.
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
