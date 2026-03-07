import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    // ──────────────────────────────────────────────
    // Edit properties (local state, saved only on Apply)
    // ──────────────────────────────────────────────

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

    // Derived from editIconTheme
    readonly property string editBaseTheme: editIconTheme.startsWith("adwaita") ? "adwaita" : "papirus"
    readonly property string editMethod: editIconTheme === "adwaita-match" ? "match" : "recolor"

    function computeIconTheme(baseTheme, method) {
        if (baseTheme === "papirus") return "papirus"
        if (method === "match") return "adwaita-match"
        return "adwaita-recolor"
    }

    // ──────────────────────────────────────────────
    // Appearance
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: appearanceContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
            id: appearanceContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                text: "Appearance"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }

            NColorChoice {
                label: "Accent source"
                description: "Which theme color to use for folder icons"
                currentKey: root.editAccentSource
                onSelected: key => {
                    root.editAccentSource = key
                }
            }

            NComboBox {
                label: "Icon theme"
                description: "Base icon theme to recolor"
                model: [
                    { "key": "papirus", "name": "Papirus" },
                    { "key": "adwaita", "name": "Adwaita" }
                ]
                currentKey: root.editBaseTheme
                onSelected: key => {
                    root.editIconTheme = root.computeIconTheme(key, root.editMethod)
                }
            }

            NText {
                visible: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return false
                    if (root.editBaseTheme === "papirus" && !mi.papirusSourceAvailable) return true
                    if (root.editBaseTheme === "adwaita" && !mi.adwaitaSourceAvailable) return true
                    return false
                }
                text: {
                    if (root.editBaseTheme === "papirus")
                        return "Papirus-Dark is not installed on this system. Install it via your package manager."
                    return "Adwaita icons are not installed on this system."
                }
                color: "#f44336"
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: methodCombo.implicitHeight
                enabled: root.editBaseTheme === "adwaita"
                opacity: enabled ? 1.0 : 0.5

                NComboBox {
                    id: methodCombo
                    anchors.fill: parent
                    label: "Method"
                    description: "Recolor copies SVGs; Closest Match uses a built-in Adwaita variant"
                    model: [
                        { "key": "recolor", "name": "Recolor" },
                        { "key": "match",   "name": "Closest Match" }
                    ]
                    currentKey: root.editMethod
                    onSelected: key => {
                        root.editIconTheme = root.computeIconTheme(root.editBaseTheme, key)
                    }
                }
            }

            NToggle {
                label: "Dim mode"
                description: "Desaturate and darken the accent color for a muted folder look"
                checked: root.editDimMode
                onToggled: {
                    root.editDimMode = checked
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // Icon Theme Status
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: statusContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
            id: statusContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                text: "Icon Theme Status"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }

            // Papirus-Noctalia row
            RowLayout {
                spacing: Style.marginS

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: {
                        const mi = pluginApi?.mainInstance
                        if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                        return mi.papirusInstalled ? "#4caf50" : "#f44336"
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                NText {
                    text: "Papirus-Noctalia"
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeM
                }

                NText {
                    text: {
                        const mi = pluginApi?.mainInstance
                        if (!mi?.installCheckDone) return "Checking..."
                        return mi.papirusInstalled ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.papirusInstalled
                    }
                    onClicked: root.launchInstall("papirus")
                }
            }

            // Adwaita-Noctalia row
            RowLayout {
                spacing: Style.marginS

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: {
                        const mi = pluginApi?.mainInstance
                        if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                        return mi.adwaitaInstalled ? "#4caf50" : "#f44336"
                    }
                    Layout.alignment: Qt.AlignVCenter
                }

                NText {
                    text: "Adwaita-Noctalia"
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeM
                }

                NText {
                    text: {
                        const mi = pluginApi?.mainInstance
                        if (!mi?.installCheckDone) return "Checking..."
                        return mi.adwaitaInstalled ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.adwaitaInstalled
                    }
                    onClicked: root.launchInstall("adwaita-recolor")
                }
            }

            NText {
                text: "Closest Match mode does not require installation."
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
            }
        }
    }

    // ──────────────────────────────────────────────
    // Behavior
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: behaviorContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
            id: behaviorContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                text: "Behavior"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }

            NToggle {
                label: "Auto-apply on theme change"
                description: "Automatically recolor folder icons when the Noctalia colorscheme changes"
                checked: root.editAutoApply
                onToggled: {
                    root.editAutoApply = checked
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // Advanced
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: advancedContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
            id: advancedContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                text: "Advanced"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }

            NButton {
                text: "Rebuild Icon Cache"
                onClicked: {
                    rebuildCacheProcess.running = true
                }
            }

            NButton {
                text: "Reset to Default Icons"
                onClicked: {
                    pluginApi?.mainInstance?.resetFolders()
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // Processes
    // ──────────────────────────────────────────────

    Process {
        id: installTerminal
        onExited: function(exitCode) {
            pluginApi?.mainInstance?.checkInstallStatus()
        }
    }

    Process {
        id: rebuildCacheProcess
        command: ["sh", "-c", [
            'gtk-update-icon-cache -qf "$HOME/.local/share/icons/Papirus-Noctalia" 2>/dev/null',
            'gtk-update-icon-cache -qf "$HOME/.local/share/icons/Adwaita-Noctalia" 2>/dev/null',
            'true'
        ].join("; ")]
        onExited: function(exitCode) {
            ToastService.showNotice("Noctalia Folders", "Icon cache rebuilt", "folder")
        }
    }

    // ──────────────────────────────────────────────
    // Functions
    // ──────────────────────────────────────────────

    function launchInstall(iconTheme) {
        const mi = pluginApi?.mainInstance
        if (!mi) return
        const script = mi.scriptPath
        const cmd = `"${script}" --install --icon-theme ${iconTheme}`
        installTerminal.command = ["sh", "-c", `$TERMINAL -e sh -c '${cmd}; echo; echo "Press Enter to close..."; read _'`]
        installTerminal.running = true
    }

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

        // Trigger recolor with new settings
        pluginApi?.mainInstance?.applyFolders()

        Logger.i("NoctaliaFolders", "Settings saved successfully")
    }
}
