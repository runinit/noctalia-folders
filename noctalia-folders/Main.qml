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

    // Install detection — Noctalia copies
    property bool papirusInstalled: false
    property bool adwaitaInstalled: false
    property bool installCheckDone: false

    // Dependency detection — upstream packages (values: "user", "system", "1", or "0")
    property string papirusIconThemeAvailable: "0"
    property string papirusFoldersAvailable: "0"
    property string adwaitaBaseAvailable: "0"
    property string adwaitaColorsAvailable: "0"
    property string morewaitaAvailable: "0"

    // Settings shortcuts
    readonly property bool enabled: pluginApi?.pluginSettings?.enabled ?? false
    readonly property bool autoApply: pluginApi?.pluginSettings?.autoApply ?? true
    readonly property string iconTheme: pluginApi?.pluginSettings?.iconTheme || "papirus-recolor"
    readonly property bool dimMode: pluginApi?.pluginSettings?.dimMode ?? false
    readonly property string accentSource: pluginApi?.pluginSettings?.accentSource || "mPrimary"
    readonly property bool debugMode: pluginApi?.pluginSettings?.debugMode ?? false
    readonly property bool setGtkTheme: pluginApi?.pluginSettings?.setGtkTheme ?? true
    readonly property bool setQtTheme: pluginApi?.pluginSettings?.setQtTheme ?? true
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
        if (!root.setGtkTheme) cmd += " --no-set-gtk"
        if (!root.setQtTheme) cmd += " --no-set-qt"
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
        if (root.enabled && root.autoApply && !root.isRunning && root._currentFingerprint() !== root.lastAppliedFingerprint) {
            Logger.i("NoctaliaFolders", reason)
            root.applyFolders()
        }
    }

    function _onAccentChanged() {
        root._autoApplyIfChanged(`Accent (${root.accentSource}) changed to ${root.currentAccentColor}, auto-applying...`)
    }

    Component.onCompleted: {
        root.checkInstallStatus()
        if (root.enabled) {
            stateCheckProcess.running = true
            startupTimer.running = true
        }
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

        function enable() {
            if (pluginApi) {
                pluginApi.pluginSettings.enabled = true
                pluginApi.saveSettings()
                root.checkInstallStatus()
                stateCheckProcess.running = true
                startupTimer.running = true
            }
        }

        function disable() {
            if (pluginApi) {
                pluginApi.pluginSettings.enabled = false
                pluginApi.saveSettings()
                root.resetFolders()
            }
        }
    }

    // ──────────────────────────────────────────────
    // Script execution
    // ──────────────────────────────────────────────

    function applyFolders(overrideIconTheme, overrideAccentSource, overrideDimMode) {
        if (!root.enabled || root.isRunning) return
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
        command: ["sh", "-c", `"${root.scriptPath}" --check-deps`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const [key, val] = line.split("=")
                    if (key === "papirus_icon_theme") root.papirusIconThemeAvailable = val
                    if (key === "papirus_folders") root.papirusFoldersAvailable = val
                    if (key === "adwaita_base") root.adwaitaBaseAvailable = val
                    if (key === "adwaita_colors") root.adwaitaColorsAvailable = val
                    if (key === "morewaita") root.morewaitaAvailable = val
                    if (key === "papirus_installed") root.papirusInstalled = val === "1"
                    if (key === "adwaita_installed") root.adwaitaInstalled = val === "1"
                }
                root.installCheckDone = true
                Logger.i("NoctaliaFolders", `Deps: papirus-icon-theme=${root.papirusIconThemeAvailable}, papirus-folders=${root.papirusFoldersAvailable}, adwaita=${root.adwaitaBaseAvailable}, adwaita-colors=${root.adwaitaColorsAvailable}, morewaita=${root.morewaitaAvailable}`)
            }
        }
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                Logger.e("NoctaliaFolders", `Dep check failed with exit code ${exitCode}`)
                root.installCheckDone = true
            }
        }
    }
}
