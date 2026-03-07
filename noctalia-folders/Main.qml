import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    // Track state
    property string lastAppliedFingerprint: ""
    property bool isRunning: false

    function _currentFingerprint() {
        return `${root.currentAccentColor}|${root.dimMode}|${root.iconTheme}`
    }

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
    readonly property bool debugMode: pluginApi?.pluginSettings?.debugMode ?? false
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
    // Optional overrides bypass async QML bindings (used by saveSettings)
    function buildCmd(operation, overrideIconTheme, overrideAccentSource, overrideDimMode) {
        const theme = overrideIconTheme ?? root.iconTheme
        const source = overrideAccentSource ?? root.accentSource
        const dim = overrideDimMode ?? root.dimMode
        let cmd = `"${root.scriptPath}" ${operation} --icon-theme ${theme} --color-source ${source}`
        if (dim) cmd += " --dim"
        if (root.debugMode) cmd += " --verbose"
        return cmd
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

    function _autoApplyIfChanged(reason) {
        if (root.autoApply && !root.isRunning && root._currentFingerprint() !== root.lastAppliedFingerprint) {
            Logger.i("NoctaliaFolders", reason)
            root.applyFolders()
        }
    }

    function _onAccentChanged() {
        root._autoApplyIfChanged(`Accent (${root.accentSource}) changed to ${root.currentAccentColor}, auto-applying...`)
    }

    // Settings-change handlers removed — only the Color singleton
    // watcher (above) and the explicit Apply button trigger recoloring.

    Component.onCompleted: {
        root.checkInstallStatus()
        stateCheckProcess.running = true
        startupTimer.running = true
    }

    Timer {
        id: startupTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            root._autoApplyIfChanged("Startup timer triggered, applying...")
        }
    }

    Process {
        id: stateCheckProcess
        command: ["sh", "-c", `cat "$HOME/.config/noctalia-folders/state" 2>/dev/null || echo ""`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                let color = ""
                let mode = ""
                let dim = ""
                for (const line of lines) {
                    const eqIdx = line.indexOf("=")
                    if (eqIdx < 0) continue
                    const key = line.substring(0, eqIdx)
                    const val = line.substring(eqIdx + 1)
                    if (key === "color") color = val
                    if (key === "mode") mode = val
                    if (key === "dim") dim = val
                }
                if (color && mode && dim) {
                    const stateFp = `${color}|${dim === "true"}|${mode}`
                    const currentFp = root._currentFingerprint()
                    if (stateFp === currentFp) {
                        Logger.i("NoctaliaFolders", "State file matches current settings, skipping startup apply")
                        root.lastAppliedFingerprint = currentFp
                    }
                }
            }
        }
        stderr: StdioCollector {}
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

    function applyFolders(overrideIconTheme, overrideAccentSource, overrideDimMode) {
        if (root.isRunning) return
        root.isRunning = true
        applyProcess.command = ["sh", "-c", root.buildCmd("--apply", overrideIconTheme, overrideAccentSource, overrideDimMode)]
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
                root.lastAppliedFingerprint = root._currentFingerprint()
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
            root.lastAppliedFingerprint = ""
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
