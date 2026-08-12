import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Shesh settings — local AI body (Brain + Mind + Soma).
// Toggles here write to the shell config; systemd units read the same values.
ContentPage {
    forceWidth: true

    ContentSection {
        icon: "psychology_alt"
        title: Translation.tr("Shesh")

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Enable Shesh")
            checked: Config.options.shesh.enabled
            onCheckedChanged: Config.options.shesh.enabled = checked
            StyledToolTip {
                text: Translation.tr("Master switch for the local AI agent and automations")
            }
        }
        ConfigSwitch {
            buttonIcon: "mic"
            text: Translation.tr("Voice wake word")
            enabled: Config.options.shesh.enabled
            checked: Config.options.shesh.voiceWakeWord
            onCheckedChanged: Config.options.shesh.voiceWakeWord = checked
            StyledToolTip {
                text: Translation.tr("Answer to \"Hey Shesh\" via Newelle (local, no cloud)")
            }
        }
    }

    ContentSection {
        icon: "auto_fix_high"
        title: Translation.tr("Automation")

        ConfigSwitch {
            buttonIcon: "folder_managed"
            text: Translation.tr("Realtime file organizer")
            enabled: Config.options.shesh.enabled
            checked: Config.options.shesh.realtimeOrganizer
            onCheckedChanged: Config.options.shesh.realtimeOrganizer = checked
            StyledToolTip {
                text: Translation.tr("Watch Downloads/Desktop and sort new files automatically")
            }
        }
        ConfigSwitch {
            buttonIcon: "battery_saver"
            text: Translation.tr("Auto power profile")
            enabled: Config.options.shesh.enabled
            checked: Config.options.shesh.autoPowerProfile
            onCheckedChanged: Config.options.shesh.autoPowerProfile = checked
            StyledToolTip {
                text: Translation.tr("Switch to performance on AC and power-saver on battery")
            }
        }
        ConfigSwitch {
            buttonIcon: "ink_marker"
            text: Translation.tr("Reduce visuals on battery")
            enabled: Config.options.shesh.enabled && Config.options.shesh.autoPowerProfile
            checked: Config.options.shesh.lowPowerVisuals
            onCheckedChanged: Config.options.shesh.lowPowerVisuals = checked
        }
        ConfigSwitch {
            buttonIcon: "backup"
            text: Translation.tr("Automatic backups")
            enabled: Config.options.shesh.enabled
            checked: Config.options.shesh.autoBackup
            onCheckedChanged: Config.options.shesh.autoBackup = checked
            StyledToolTip {
                text: Translation.tr("Run the local restic backup on a schedule (requires setup)")
            }
        }

        ConfigSpinBox {
            icon: "help_clinic"
            text: Translation.tr("Auto-organize confidence (%)")
            enabled: Config.options.shesh.enabled && Config.options.shesh.realtimeOrganizer
            value: Config.options.shesh.organizerConfidence
            from: 0
            to: 100
            stepSize: 5
            onValueChanged: Config.options.shesh.organizerConfidence = value
            StyledToolTip {
                text: Translation.tr("Below this confidence, Shesh asks before moving a file")
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Local models")

        StyledComboBox {
            id: llmSelector
            buttonIcon: "brain"
            textRole: "displayName"
            enabled: Config.options.shesh.enabled

            model: [
                { displayName: "phi4-mini (3.8B, default)", value: "phi4-mini" },
                { displayName: "qwen2.5-coder:3b (code)", value: "qwen2.5-coder:3b" },
                { displayName: "gemma2:2b (fast)", value: "gemma2:2b" }
            ]
            currentIndex: {
                const i = model.findIndex(m => m.value === Config.options.shesh.llmModel)
                return i !== -1 ? i : 0
            }
            onActivated: index => Config.options.shesh.llmModel = model[index].value
        }

        StyledComboBox {
            buttonIcon: "center_focus_strong"
            textRole: "displayName"
            enabled: Config.options.shesh.enabled
            model: [
                { displayName: "moondream2 (vision)", value: "moondream2" },
                { displayName: "off", value: "off" }
            ]
            currentIndex: Config.options.shesh.visionModel === "off" ? 1 : 0
            onActivated: index => Config.options.shesh.visionModel = model[index].value
        }

        StyledComboBox {
            buttonIcon: "cloud_off"
            textRole: "displayName"
            enabled: Config.options.shesh.enabled
            model: [
                { displayName: Translation.tr("Off (local only)"), value: "off" },
                { displayName: Translation.tr("Opt-in cloud fallback"), value: "opt-in" }
            ]
            currentIndex: Config.options.shesh.cloudTier === "opt-in" ? 1 : 0
            onActivated: index => Config.options.shesh.cloudTier = model[index].value
            StyledToolTip {
                text: Translation.tr("Cloud is never used unless you explicitly confirm per request")
            }
        }
    }

    ContentSection {
        icon: "verified"
        title: Translation.tr("Governance")

        ConfigRow {
            uniform: false
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Every action Shesh takes is recorded in an append-only audit log. Destructive actions always ask for confirmation.")
                wrapMode: Text.WordWrap
            }
        }
    }
}
