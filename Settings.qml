import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    property bool editAutoApply:
        pluginApi?.pluginSettings?.autoApply ??
        pluginApi?.manifest?.metadata?.defaultSettings?.autoApply ??
        true

    property string editIconTheme:
        pluginApi?.pluginSettings?.iconTheme ||
        pluginApi?.manifest?.metadata?.defaultSettings?.iconTheme ||
        "papirus"

    property bool editDimMode:
        pluginApi?.pluginSettings?.dimMode ??
        pluginApi?.manifest?.metadata?.defaultSettings?.dimMode ??
        false

    property string editAccentSource:
        pluginApi?.pluginSettings?.accentSource ||
        pluginApi?.manifest?.metadata?.defaultSettings?.accentSource ||
        "mPrimary"

    function colorForKey(key) {
        switch (key) {
        case "mPrimary":   return Color.mPrimary || "#888888"
        case "mSecondary": return Color.mSecondary || "#888888"
        case "mTertiary":  return Color.mTertiary || "#888888"
        case "mHover":     return Color.mHover || "#888888"
        default:           return "#888888"
        }
    }

    function dimColor(hexColor) {
        if (!hexColor || hexColor === "#888888") return hexColor
        const r = parseInt(hexColor.substring(1, 3), 16) / 255
        const g = parseInt(hexColor.substring(3, 5), 16) / 255
        const b = parseInt(hexColor.substring(5, 7), 16) / 255
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        let h, s, l = (max + min) / 2
        if (max === min) {
            h = s = 0
        } else {
            const d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            switch (max) {
            case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break
            case g: h = ((b - r) / d + 2) / 6; break
            case b: h = ((r - g) / d + 4) / 6; break
            }
        }
        s *= 0.70
        l *= 0.85
        function hue2rgb(p, q, t) {
            if (t < 0) t += 1
            if (t > 1) t -= 1
            if (t < 1/6) return p + (q - p) * 6 * t
            if (t < 1/2) return q
            if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
            return p
        }
        let r2, g2, b2
        if (s === 0) {
            r2 = g2 = b2 = l
        } else {
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s
            const p = 2 * l - q
            r2 = hue2rgb(p, q, h + 1/3)
            g2 = hue2rgb(p, q, h)
            b2 = hue2rgb(p, q, h - 1/3)
        }
        const toHex = v => {
            const hex = Math.round(v * 255).toString(16)
            return hex.length === 1 ? "0" + hex : hex
        }
        return "#" + toHex(r2) + toHex(g2) + toHex(b2)
    }

    function displayColor(key) {
        const base = colorForKey(key)
        return root.editDimMode ? dimColor(base) : base
    }

    // ──────────────────────────────────────────────
    // Accent color source selector (swatches with labels)
    // ──────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Repeater {
            model: [
                { key: "mPrimary",   label: "Primary" },
                { key: "mSecondary", label: "Secondary" },
                { key: "mTertiary",  label: "Tertiary" },
                { key: "mHover",     label: "Hover" }
            ]

            delegate: ColumnLayout {
                spacing: 4

                Rectangle {
                    width: 36
                    height: 36
                    radius: width / 2
                    color: root.displayColor(modelData.key)
                    border.width: root.editAccentSource === modelData.key ? 3 : 1
                    border.color: root.editAccentSource === modelData.key
                        ? Color.mOnSurface || "#ffffff"
                        : Color.mOutline || "#555555"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editAccentSource = modelData.key
                            pluginApi?.mainInstance?.applyWithOverrides(
                                root.editAccentSource, root.editDimMode)
                        }
                    }
                }

                Text {
                    text: modelData.label
                    color: root.editAccentSource === modelData.key
                        ? Color.mOnSurface || "#ffffff"
                        : Color.mOutline || "#888888"
                    font.pixelSize: 11
                    font.bold: root.editAccentSource === modelData.key
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // ──────────────────────────────────────────────
    // Icon theme mode selector
    // ──────────────────────────────────────────────

    NComboBox {
        label: "Icon theme mode"
        description: "Choose how folder icons are themed"
        model: {
            const mi = pluginApi?.mainInstance
            const pOk = mi?.papirusInstalled ?? false
            const aOk = mi?.adwaitaInstalled ?? false
            return [
                {
                    "key": "papirus",
                    "name": pOk ? "Papirus (Recolored)" : "Papirus (Not installed)"
                },
                {
                    "key": "adwaita-match",
                    "name": aOk ? "Adwaita (Closest Match)" : "Adwaita (Not installed)"
                },
                {
                    "key": "adwaita-recolor",
                    "name": aOk ? "Adwaita (Recolored)" : "Adwaita (Not installed)"
                }
            ]
        }
        currentKey: root.editIconTheme
        onSelected: key => root.editIconTheme = key
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.iconTheme || "papirus"
    }

    NDivider {
        Layout.fillWidth: true
    }

    // ──────────────────────────────────────────────
    // Dim mode toggle
    // ──────────────────────────────────────────────

    NToggle {
        label: "Dim mode"
        description: "Desaturate and darken the accent color for a muted folder look"
        checked: root.editDimMode
        onToggled: {
            root.editDimMode = checked
            pluginApi?.mainInstance?.applyWithOverrides(
                root.editAccentSource, root.editDimMode)
        }
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.dimMode ?? false
    }

    // ──────────────────────────────────────────────
    // Auto-apply toggle
    // ──────────────────────────────────────────────

    NToggle {
        label: "Auto-apply on theme change"
        description: "Automatically recolor folder icons when the Noctalia colorscheme changes"
        checked: root.editAutoApply
        onToggled: root.editAutoApply = checked
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.autoApply ?? true
    }

    NDivider {
        Layout.fillWidth: true
    }

    // ──────────────────────────────────────────────
    // Status info
    // ──────────────────────────────────────────────

    NLabel {
        label: "Status"
        description: {
            const mi = pluginApi?.mainInstance
            if (!mi?.installCheckDone) return "Checking installation..."

            let lines = []

            if (mi.papirusSourceAvailable) {
                lines.push("Papirus: " + (mi.papirusInstalled ? "Installed" : "Not installed"))
            } else {
                lines.push("Papirus: Source not available")
            }

            if (mi.adwaitaSourceAvailable) {
                lines.push("Adwaita: " + (mi.adwaitaInstalled ? "Installed" : "Not installed"))
            } else {
                lines.push("Adwaita: Source not available")
            }

            const lastApplied = mi.lastAppliedColor || "none"
            lines.push("Last applied: " + lastApplied)

            if (mi.isRunning) lines.push("Recoloring...")

            return lines.join("\n")
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // ──────────────────────────────────────────────
    // Manual actions
    // ──────────────────────────────────────────────

    RowLayout {
        spacing: Style.marginM

        NButton {
            text: "Reset to Default"
            onClicked: {
                pluginApi?.mainInstance?.resetFolders()
            }
        }

        NButton {
            text: "Install Theme"
            onClicked: {
                pluginApi?.mainInstance?.installTheme()
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    // ──────────────────────────────────────────────
    // Save
    // ──────────────────────────────────────────────

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("NoctaliaFolders", "Cannot save: pluginApi is null")
            return
        }

        pluginApi.pluginSettings.autoApply = root.editAutoApply
        pluginApi.pluginSettings.iconTheme = root.editIconTheme
        pluginApi.pluginSettings.dimMode = root.editDimMode
        pluginApi.pluginSettings.accentSource = root.editAccentSource

        pluginApi.saveSettings()

        Logger.i("NoctaliaFolders", "Settings saved successfully")
    }
}
