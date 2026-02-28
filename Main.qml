import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // Track state
    property string lastAppliedColor: ""
    property bool isRunning: false

    // Install detection
    property bool papirusInstalled: false
    property bool adwaitaInstalled: false
    property bool papirusSourceAvailable: false
    property bool adwaitaSourceAvailable: false
    property bool installCheckDone: false

    // Settings shortcuts
    readonly property bool autoApply: pluginApi?.pluginSettings?.autoApply ?? true
    readonly property string iconTheme: pluginApi?.pluginSettings?.iconTheme || "papirus"
    readonly property bool dimMode: pluginApi?.pluginSettings?.dimMode ?? false
    readonly property string accentSource: pluginApi?.pluginSettings?.accentSource || "mPrimary"
    readonly property string scriptPath: {
        const pluginDir = Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
        return pluginDir + "/scripts/noctalia-folders"
    }

    // Resolve the current accent color based on selected source
    readonly property string currentAccentColor: {
        switch (root.accentSource) {
        case "mSecondary": return Color.mSecondary || ""
        case "mTertiary":  return Color.mTertiary || ""
        case "mHover":     return Color.mHover || ""
        default:           return Color.mPrimary || ""
        }
    }

    // Build command with current settings flags
    function buildCmd(operation) {
        let cmd = `"${root.scriptPath}" ${operation} --icon-theme ${root.iconTheme} --color-source ${root.accentSource}`
        if (root.dimMode) cmd += " --dim"
        return cmd
    }

    // Build and run a one-shot apply with explicit parameters
    // (used by Settings.qml for instant preview before framework save)
    function applyWithOverrides(overrideAccentSource, overrideDimMode) {
        if (root.isRunning) return
        root.isRunning = true
        let cmd = `"${root.scriptPath}" --apply --icon-theme ${root.iconTheme} --color-source ${overrideAccentSource}`
        if (overrideDimMode) cmd += " --dim"
        applyProcess.command = ["sh", "-c", cmd]
        applyProcess.running = true
    }

    // ──────────────────────────────────────────────
    // Auto-apply on color change
    // ──────────────────────────────────────────────

    // Watch all four color properties — only trigger when our
    // selected source actually changes
    Connections {
        target: Color

        function onMPrimaryChanged() {
            if (root.accentSource === "mPrimary") root._onAccentChanged()
        }
        function onMSecondaryChanged() {
            if (root.accentSource === "mSecondary") root._onAccentChanged()
        }
        function onMTertiaryChanged() {
            if (root.accentSource === "mTertiary") root._onAccentChanged()
        }
        function onMHoverChanged() {
            if (root.accentSource === "mHover") root._onAccentChanged()
        }
    }

    function _onAccentChanged() {
        if (root.autoApply && !root.isRunning) {
            Logger.i("NoctaliaFolders", `Accent (${root.accentSource}) changed to ${root.currentAccentColor}, auto-applying...`)
            root.applyFolders()
        }
    }

    // Also re-apply when the user switches accent source
    onAccentSourceChanged: {
        if (root.autoApply && !root.isRunning && root.currentAccentColor) {
            Logger.i("NoctaliaFolders", `Accent source changed to ${root.accentSource} (${root.currentAccentColor}), re-applying...`)
            root.applyFolders()
        }
    }

    onDimModeChanged: {
        if (root.autoApply && !root.isRunning && root.currentAccentColor) {
            Logger.i("NoctaliaFolders", `Dim mode changed to ${root.dimMode}, re-applying...`)
            root.applyFolders()
        }
    }

    onIconThemeChanged: {
        if (root.autoApply && !root.isRunning && root.currentAccentColor) {
            Logger.i("NoctaliaFolders", `Icon theme changed to ${root.iconTheme}, re-applying...`)
            root.applyFolders()
        }
    }

    Component.onCompleted: {
        startupTimer.running = true
        root.checkInstallStatus()
    }

    Timer {
        id: startupTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            if (root.autoApply) {
                root.applyFolders()
            }
        }
    }

    // ──────────────────────────────────────────────
    // IPC Handler
    // ──────────────────────────────────────────────

    IpcHandler {
        target: "plugin:noctalia-folders"

        function apply() {
            root.applyFolders()
        }

        function reset() {
            root.resetFolders()
        }

        function status() {
            root.statusCheck()
        }

        function install() {
            root.installTheme()
        }
    }

    // ──────────────────────────────────────────────
    // Script execution
    // ──────────────────────────────────────────────

    function applyFolders() {
        if (root.isRunning) return
        root.isRunning = true
        applyProcess.command = ["sh", "-c", root.buildCmd("--apply")]
        applyProcess.running = true
    }

    function resetFolders() {
        if (root.isRunning) return
        root.isRunning = true
        resetProcess.command = ["sh", "-c", root.buildCmd("--reset")]
        resetProcess.running = true
    }

    function statusCheck() {
        statusProcess.command = ["sh", "-c", root.buildCmd("--status")]
        statusProcess.running = true
    }

    function installTheme() {
        if (root.isRunning) return
        root.isRunning = true
        installProcess.command = ["sh", "-c", root.buildCmd("--install")]
        installProcess.running = true
    }

    function checkInstallStatus() {
        installCheckProcess.running = true
    }

    // ──────────────────────────────────────────────
    // Process objects
    // ──────────────────────────────────────────────

    Process {
        id: applyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                Logger.i("NoctaliaFolders", `Apply: ${text.trim()}`)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) Logger.e("NoctaliaFolders", `Apply error: ${text.trim()}`)
            }
        }
        onExited: function(exitCode) {
            root.isRunning = false
            if (exitCode === 0) {
                root.lastAppliedColor = root.currentAccentColor
                Logger.i("NoctaliaFolders", "Folders recolored successfully")
                ToastService.showNotice("Noctalia Folders", "Folder icons recolored!", "folder")
            } else {
                Logger.e("NoctaliaFolders", `Apply failed with exit code ${exitCode}`)
                ToastService.showError("Noctalia Folders", "Failed to recolor folder icons")
            }
        }
    }

    Process {
        id: resetProcess
        stdout: StdioCollector {
            onStreamFinished: {
                Logger.i("NoctaliaFolders", `Reset: ${text.trim()}`)
            }
        }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            root.isRunning = false
            root.lastAppliedColor = ""
            if (exitCode === 0) {
                Logger.i("NoctaliaFolders", "Folders reset to defaults")
                ToastService.showNotice("Noctalia Folders", "Folder icons reset to defaults", "folder")
            } else {
                Logger.e("NoctaliaFolders", `Reset failed with exit code ${exitCode}`)
                ToastService.showError("Noctalia Folders", "Failed to reset folder icons")
            }
        }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                Logger.i("NoctaliaFolders", `Status: ${output}`)
            }
        }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                Logger.e("NoctaliaFolders", `Status check failed with exit code ${exitCode}`)
            }
        }
    }

    Process {
        id: installProcess
        stdout: StdioCollector {
            onStreamFinished: {
                Logger.i("NoctaliaFolders", `Install: ${text.trim()}`)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) Logger.e("NoctaliaFolders", `Install error: ${text.trim()}`)
            }
        }
        onExited: function(exitCode) {
            root.isRunning = false
            if (exitCode === 0) {
                Logger.i("NoctaliaFolders", "Icon theme installed successfully")
                ToastService.showNotice("Noctalia Folders", "Icon theme installed!", "folder")
                root.checkInstallStatus()
                if (root.autoApply) {
                    root.applyFolders()
                }
            } else {
                Logger.e("NoctaliaFolders", `Install failed with exit code ${exitCode}`)
                ToastService.showError("Noctalia Folders", "Failed to install icon theme")
            }
        }
    }

    Process {
        id: installCheckProcess
        command: ["sh", "-c", `
            echo "papirus_installed=$([ -d "$HOME/.local/share/icons/Papirus-Noctalia" ] && echo 1 || echo 0)"
            echo "adwaita_installed=$([ -d "$HOME/.local/share/icons/Adwaita-Noctalia" ] && echo 1 || echo 0)"
            echo "papirus_source=$([ -d /usr/share/icons/Papirus-Dark ] && echo 1 || echo 0)"
            echo "adwaita_source=$([ -d /usr/share/icons/Adwaita ] && echo 1 || echo 0)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const [key, val] = line.split("=")
                    if (key === "papirus_installed") root.papirusInstalled = val === "1"
                    if (key === "adwaita_installed") root.adwaitaInstalled = val === "1"
                    if (key === "papirus_source") root.papirusSourceAvailable = val === "1"
                    if (key === "adwaita_source") root.adwaitaSourceAvailable = val === "1"
                }
                root.installCheckDone = true
                Logger.i("NoctaliaFolders", `Install check: Papirus=${root.papirusInstalled}, Adwaita=${root.adwaitaInstalled}`)
            }
        }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                Logger.e("NoctaliaFolders", `Install check failed with exit code ${exitCode}`)
                root.installCheckDone = true
            }
        }
    }
}
