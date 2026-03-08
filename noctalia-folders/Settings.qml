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

    property bool editEnabled:
        pluginApi?.pluginSettings?.enabled ??
        pluginApi?.manifest?.metadata?.defaultSettings?.enabled ??
        false

    property bool editAutoApply:
        pluginApi?.pluginSettings?.autoApply ??
        pluginApi?.manifest?.metadata?.defaultSettings?.autoApply ??
        true

    property string editIconTheme:
        pluginApi?.pluginSettings?.iconTheme ||
        pluginApi?.manifest?.metadata?.defaultSettings?.iconTheme ||
        "papirus-recolor"

    property bool editDimMode:
        pluginApi?.pluginSettings?.dimMode ??
        pluginApi?.manifest?.metadata?.defaultSettings?.dimMode ??
        false

    property string editAccentSource: {
        const saved = pluginApi?.pluginSettings?.accentSource ||
            pluginApi?.manifest?.metadata?.defaultSettings?.accentSource ||
            "mPrimary"
        // NColorChoice uses unprefixed keys (e.g. "primary" not "mPrimary")
        if (saved.startsWith("m") && saved.length > 1)
            return saved.charAt(1).toLowerCase() + saved.slice(2)
        return saved
    }

    property bool editSetGtkTheme:
        pluginApi?.pluginSettings?.setGtkTheme ??
        pluginApi?.manifest?.metadata?.defaultSettings?.setGtkTheme ??
        true

    property bool editSetQtTheme:
        pluginApi?.pluginSettings?.setQtTheme ??
        pluginApi?.manifest?.metadata?.defaultSettings?.setQtTheme ??
        true

    // Derived from editIconTheme
    readonly property string editBaseTheme: editIconTheme.startsWith("adwaita") ? "adwaita" : "papirus"
    readonly property string editMethod: editIconTheme.endsWith("-match") ? "match" : "recolor"

    function computeIconTheme(baseTheme, method) {
        return baseTheme + "-" + method
    }

    // (collapsible sections use NCollapsible with internal expanded state)

    // ──────────────────────────────────────────────
    // Enable Switch
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: enableContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
            id: enableContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NToggle {
                label: "Enable Noctalia Folders"
                description: "Recolor folder icons to match your accent color"
                checked: root.editEnabled
                onToggled: {
                    root.editEnabled = checked
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // Appearance
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: appearanceContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

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

            NComboBox {
                label: "Method"
                description: "Recolor modifies SVGs; Closest Match picks a preset"
                model: [
                    { "key": "recolor", "name": "Recolor" },
                    { "key": "match",   "name": "Closest Match" }
                ]
                currentKey: root.editMethod
                onSelected: key => {
                    root.editIconTheme = root.computeIconTheme(root.editBaseTheme, key)
                }
            }

            NText {
                visible: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return false
                    if (root.editBaseTheme === "papirus") {
                        if (root.editMethod === "recolor" && mi.papirusIconThemeAvailable === "0") return true
                        if (root.editMethod === "match" && mi.papirusFoldersAvailable === "0") return true
                    }
                    if (root.editBaseTheme === "adwaita") {
                        if (root.editMethod === "recolor" && mi.adwaitaBaseAvailable === "0") return true
                        if (root.editMethod === "match" && mi.adwaitaColorsAvailable === "0") return true
                    }
                    return false
                }
                text: {
                    if (root.editBaseTheme === "papirus") {
                        if (root.editMethod === "match")
                            return "papirus-folders is not installed. Install it from Dependency Status below."
                        return "Papirus-Dark is not installed. Install it from Dependency Status below."
                    }
                    if (root.editMethod === "match")
                        return "Adwaita Colors is not installed. Install it from Dependency Status below."
                    return "Adwaita icons are not installed on this system."
                }
                color: "#f44336"
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
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
    // Dependency Status
    // ──────────────────────────────────────────────

    NCollapsible {
        Layout.fillWidth: true
        label: "Dependency Status"
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        // ── Papirus ──

        NText {
            text: "Papirus"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
        }

        // papirus-icon-theme
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10; height: 10; radius: 5
                color: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                    if (mi.papirusIconThemeAvailable === "user" || mi.papirusIconThemeAvailable === "system") return "#4caf50"
                    if (root.editBaseTheme === "papirus" && root.editMethod === "recolor") return "#f44336"
                    return Color.mOnSurfaceVariant
                }
                Layout.alignment: Qt.AlignVCenter
            }
            NText {
                text: "papirus-icon-theme"
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
            NText {
                text: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return "Checking..."
                    if (mi.papirusIconThemeAvailable === "user") return "Installed (user)"
                    if (mi.papirusIconThemeAvailable === "system") return "Installed (system)"
                    return "Not installed"
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }
            Item { Layout.fillWidth: true }
            NButton {
                text: "Install"
                visible: {
                    const mi = pluginApi?.mainInstance
                    return mi?.installCheckDone && mi.papirusIconThemeAvailable === "0"
                }
                onClicked: root.launchInstallDep("papirus-icon-theme")
            }
        }

        // papirus-folders
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10; height: 10; radius: 5
                color: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                    if (mi.papirusFoldersAvailable === "1") return "#4caf50"
                    if (root.editBaseTheme === "papirus" && root.editMethod === "match") return "#f44336"
                    return Color.mOnSurfaceVariant
                }
                Layout.alignment: Qt.AlignVCenter
            }
            NText {
                text: "papirus-folders"
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
            NText {
                text: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return "Checking..."
                    return mi.papirusFoldersAvailable === "1" ? "Installed" : "Not installed"
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }
            Item { Layout.fillWidth: true }
            NButton {
                text: "Install"
                visible: {
                    const mi = pluginApi?.mainInstance
                    return mi?.installCheckDone && mi.papirusFoldersAvailable === "0"
                }
                onClicked: root.launchInstallDep("papirus-folders")
            }
        }

        // ── Adwaita ──

        NText {
            text: "Adwaita"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.topMargin: Style.marginS
        }

        // Adwaita (base)
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10; height: 10; radius: 5
                color: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                    if (mi.adwaitaBaseAvailable === "user" || mi.adwaitaBaseAvailable === "system") return "#4caf50"
                    if (root.editBaseTheme === "adwaita" && root.editMethod === "recolor") return "#f44336"
                    return Color.mOnSurfaceVariant
                }
                Layout.alignment: Qt.AlignVCenter
            }
            NText {
                text: "Adwaita (base)"
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
            NText {
                text: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return "Checking..."
                    if (mi.adwaitaBaseAvailable === "user") return "Installed (user)"
                    if (mi.adwaitaBaseAvailable === "system") return "Installed (system)"
                    return "Not installed"
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }
            Item { Layout.fillWidth: true }
        }

        // Adwaita Colors
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10; height: 10; radius: 5
                color: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                    if (mi.adwaitaColorsAvailable === "user" || mi.adwaitaColorsAvailable === "system") return "#4caf50"
                    if (root.editBaseTheme === "adwaita" && root.editMethod === "match") return "#f44336"
                    return Color.mOnSurfaceVariant
                }
                Layout.alignment: Qt.AlignVCenter
            }
            NText {
                text: "Adwaita Colors"
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
            NText {
                text: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return "Checking..."
                    if (mi.adwaitaColorsAvailable === "user") return "Installed (user)"
                    if (mi.adwaitaColorsAvailable === "system") return "Installed (system)"
                    return "Not installed"
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }
            Item { Layout.fillWidth: true }
            NButton {
                text: "Install"
                visible: {
                    const mi = pluginApi?.mainInstance
                    return mi?.installCheckDone && mi.adwaitaColorsAvailable === "0"
                }
                onClicked: root.launchInstallDep("adwaita-colors")
            }
        }

        // MoreWaita
        RowLayout {
            spacing: Style.marginS

            Rectangle {
                width: 10; height: 10; radius: 5
                color: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return Color.mOnSurfaceVariant
                    if (mi.morewaitaAvailable === "user" || mi.morewaitaAvailable === "system") return "#4caf50"
                    if (root.editBaseTheme === "adwaita") return "#f44336"
                    return Color.mOnSurfaceVariant
                }
                Layout.alignment: Qt.AlignVCenter
            }
            NText {
                text: "MoreWaita"
                color: Color.mOnSurface
                pointSize: Style.fontSizeM
            }
            NText {
                text: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return "Checking..."
                    if (mi.morewaitaAvailable === "user") return "Installed (user)"
                    if (mi.morewaitaAvailable === "system") return "Installed (system)"
                    return "Not installed"
                }
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }
            Item { Layout.fillWidth: true }
            NButton {
                text: "Install"
                visible: {
                    const mi = pluginApi?.mainInstance
                    return mi?.installCheckDone && mi.morewaitaAvailable === "0"
                }
                onClicked: root.launchInstallDep("morewaita")
            }
        }
    }

    // ──────────────────────────────────────────────
    // Behavior (collapsible)
    // ──────────────────────────────────────────────

    NCollapsible {
        Layout.fillWidth: true
        label: "Behavior"
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        NToggle {
            label: "Auto-apply on theme change"
            description: "Automatically recolor folder icons when the Noctalia colorscheme changes"
            checked: root.editAutoApply
            onToggled: {
                root.editAutoApply = checked
            }
        }

        NToggle {
            label: "Set GTK icon theme"
            description: "Update gsettings and GTK config files when applying"
            checked: root.editSetGtkTheme
            onToggled: {
                root.editSetGtkTheme = checked
            }
        }

        NToggle {
            label: "Set QT icon theme"
            description: "Update qt5ct, qt6ct, and kdeglobals config files when applying"
            checked: root.editSetQtTheme
            onToggled: {
                root.editSetQtTheme = checked
            }
        }
    }

    // ──────────────────────────────────────────────
    // Advanced (collapsible)
    // ──────────────────────────────────────────────

    NCollapsible {
        Layout.fillWidth: true
        label: "Advanced"
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        NButton {
            text: "Rebuild Icon Cache"
            onClicked: {
                rebuildCacheProcess.running = true
            }
        }

        NToggle {
            label: "Debug logging"
            description: "Log detailed diagnostic info to console (useful for troubleshooting)"
            checked: pluginApi?.pluginSettings?.debugMode ?? false
            onToggled: {
                if (pluginApi) pluginApi.pluginSettings.debugMode = checked
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

    function launchInstallDep(depName) {
        const mi = pluginApi?.mainInstance
        if (!mi) return
        const script = mi.scriptPath
        const cmd = `"${script}" --install-dep ${depName}`
        installTerminal.command = ["sh", "-c", `$TERMINAL -e sh -c '${cmd}; echo; echo "Press Enter to close..."; read _'`]
        installTerminal.running = true
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("NoctaliaFolders", "Cannot save: pluginApi is null")
            return
        }

        const wasEnabled = pluginApi.pluginSettings.enabled ?? false

        pluginApi.pluginSettings.enabled = root.editEnabled
        pluginApi.pluginSettings.autoApply = root.editAutoApply
        pluginApi.pluginSettings.iconTheme = root.editIconTheme
        pluginApi.pluginSettings.dimMode = root.editDimMode
        pluginApi.pluginSettings.setGtkTheme = root.editSetGtkTheme
        pluginApi.pluginSettings.setQtTheme = root.editSetQtTheme
        const sourceKey = root.editAccentSource.startsWith("m")
            ? root.editAccentSource
            : "m" + root.editAccentSource.charAt(0).toUpperCase() + root.editAccentSource.slice(1)
        pluginApi.pluginSettings.accentSource = sourceKey

        pluginApi.saveSettings()

        if (root.editEnabled) {
            // Trigger recolor with explicit values (bypasses stale QML bindings)
            pluginApi?.mainInstance?.applyFolders(root.editIconTheme, sourceKey, root.editDimMode)
        } else if (wasEnabled) {
            // Was enabled, now disabled — reset folders
            pluginApi?.mainInstance?.resetFolders()
        }

        Logger.i("NoctaliaFolders", "Settings saved successfully")
    }
}
