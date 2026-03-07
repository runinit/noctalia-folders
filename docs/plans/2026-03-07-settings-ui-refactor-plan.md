# Settings UI Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the plugin settings UI with enable/disable switch, dependency management, collapsible sections, GTK/QT theme integration, and papirus-match mode.

**Architecture:** Four files change: manifest.json (new settings defaults), bash script (new modes, flags, dependency install), Main.qml (enabled gate, expanded install checks, IPC), Settings.qml (full UI restructure). Changes are layered bottom-up: bash script first (new capabilities), then Main.qml (new state/logic), then Settings.qml (new UI), then manifest.json (new defaults).

**Tech Stack:** Bash, QML (Quickshell framework), Python3 (color math)

---

### Task 1: Bash script — add `--set-gtk`/`--no-set-gtk` and `--set-qt`/`--no-set-qt` flags

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders:740-771` (globals + arg parsing)
- Modify: `noctalia-folders/scripts/noctalia-folders:650-696` (apply_icon_theme)

**Step 1: Add flag globals and parse args**

At line 742, after `COLOR_SOURCE="mPrimary"`, add:

```bash
SET_GTK="true"
SET_QT="true"
```

In the `while` loop (line 748-771), add cases before the `*)` fallthrough:

```bash
            --set-gtk)    SET_GTK="true" ;;
            --no-set-gtk) SET_GTK="false" ;;
            --set-qt)     SET_QT="true" ;;
            --no-set-qt)  SET_QT="false" ;;
```

**Step 2: Gate GTK/QT writes in `apply_icon_theme()`**

In `apply_icon_theme()` (line 650-696), wrap the GTK block (lines 661-672) with:

```bash
    if [ "$SET_GTK" = "true" ]; then
        # Force GTK to re-read icons by toggling theme away and back
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.interface icon-theme "$base_theme" 2>/dev/null
            sleep 0.5
            gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null
            msg "Set GNOME/GTK -> $theme (refreshed)"
        fi

        local gtk3_ini="$HOME/.config/gtk-3.0/settings.ini"
        [ -f "$gtk3_ini" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$gtk3_ini" 2>/dev/null || true

        local gtk4_ini="$HOME/.config/gtk-4.0/settings.ini"
        [ -f "$gtk4_ini" ] && sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$gtk4_ini" 2>/dev/null || true
    fi
```

Wrap the QT block (lines 674-695) with:

```bash
    if [ "$SET_QT" = "true" ]; then
        local kdeglobals="$HOME/.config/kdeglobals"
        if [ -f "$kdeglobals" ]; then
            if grep -q '^\[Icons\]' "$kdeglobals"; then
                sed -i "/^\[Icons\]/,/^\[/{s/^Theme=.*/Theme=$theme/}" "$kdeglobals"
            else
                printf '\n[Icons]\nTheme=%s\n' "$theme" >> "$kdeglobals"
            fi
        fi

        local qt5ct_conf="$HOME/.config/qt5ct/qt5ct.conf"
        if [ -f "$qt5ct_conf" ] && grep -q '^\[Appearance\]' "$qt5ct_conf"; then
            sed -i "/^\[Appearance\]/,/^\[/{s/^icon_theme=.*/icon_theme=$theme/}" "$qt5ct_conf"
            msg "Set qt5ct -> $theme"
        fi

        local qt6ct_conf="$HOME/.config/qt6ct/qt6ct.conf"
        if [ -f "$qt6ct_conf" ] && grep -q '^\[Appearance\]' "$qt6ct_conf"; then
            sed -i "/^\[Appearance\]/,/^\[/{s/^icon_theme=.*/icon_theme=$theme/}" "$qt6ct_conf"
            msg "Set qt6ct -> $theme"
        fi
    fi
```

**Step 3: Update usage text**

Add to the OPTIONS section:

```
  --set-gtk / --no-set-gtk   Set GTK icon theme (default: set)
  --set-qt / --no-set-qt     Set QT icon theme (default: set)
```

**Step 4: Test**

Run: `noctalia-folders --apply --no-set-gtk --no-set-qt --verbose`
Expected: Apply completes without any "Set GNOME/GTK", "Set qt5ct", "Set qt6ct" messages.

Run: `noctalia-folders --apply --verbose`
Expected: Apply sets GTK and QT themes as before.

**Step 5: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: add --set-gtk/--no-set-gtk and --set-qt/--no-set-qt flags"
```

---

### Task 2: Bash script — add `--install-dep` command for upstream dependencies

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders`

**Step 1: Add the `do_install_dep()` function**

After `do_install()` (line 403), add:

```bash
# ──────────────────────────────────────────────
# Install upstream dependencies
# ──────────────────────────────────────────────

do_install_dep() {
    local dep="$1"
    case "$dep" in
        papirus-icon-theme)
            msg "Installing papirus-icon-theme to $ICONS_USER ..."
            wget -qO- https://git.io/papirus-icon-theme-install | env DESTDIR="$ICONS_USER" sh
            msg "papirus-icon-theme installed."
            ;;
        papirus-folders)
            msg "Installing papirus-folders ..."
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            git clone --depth 1 https://github.com/PapirusDevelopmentTeam/papirus-folders.git "$tmp_dir"
            "$tmp_dir/install.sh"
            rm -rf "$tmp_dir"
            msg "papirus-folders installed."
            ;;
        adwaita-colors)
            msg "Installing Adwaita Colors to $ICONS_USER ..."
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            git clone --depth 1 https://github.com/dpejoh/Adwaita-colors.git "$tmp_dir"
            (cd "$tmp_dir" && ./setup -i)
            rm -rf "$tmp_dir"
            msg "Adwaita Colors installed."
            ;;
        morewaita)
            msg "Installing MoreWaita to $ICONS_USER ..."
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            git clone --depth 1 https://github.com/somepaulo/MoreWaita.git "$tmp_dir"
            (cd "$tmp_dir" && ./install.sh)
            rm -rf "$tmp_dir"
            msg "MoreWaita installed."
            ;;
        *)
            fatal "Unknown dependency: $dep. Valid: papirus-icon-theme, papirus-folders, adwaita-colors, morewaita"
            ;;
    esac
}
```

**Step 2: Add `--install-dep` to arg parsing**

In the `while` loop, add before `*)`:

```bash
            --install-dep)
                [ -n "${2:-}" ] || fatal "--install-dep requires an argument"
                operation="install-dep"; scheme_arg="$2"; shift ;;
```

In the `case "$operation"` dispatch, add:

```bash
        install-dep) do_install_dep "$scheme_arg" ;;
```

**Step 3: Add `--check-deps` command for QML install checks**

After `do_install_dep()`, add:

```bash
do_check_deps() {
    # Output key=value pairs for QML to parse
    local check_dir
    for check_dir in "$HOME/.local/share/icons/Papirus-Dark" "/usr/share/icons/Papirus-Dark" "/usr/local/share/icons/Papirus-Dark"; do
        [ -d "$check_dir" ] && { echo "papirus_icon_theme=1"; break; }
    done || echo "papirus_icon_theme=0"

    command -v papirus-folders &>/dev/null && echo "papirus_folders=1" || echo "papirus_folders=0"

    for check_dir in "$HOME/.local/share/icons/Adwaita" "/usr/share/icons/Adwaita" "/usr/local/share/icons/Adwaita"; do
        [ -d "$check_dir" ] && { echo "adwaita_base=1"; break; }
    done || echo "adwaita_base=0"

    local found_colors=0
    for check_dir in "$HOME/.local/share/icons" "/usr/share/icons" "/usr/local/share/icons"; do
        [ -d "$check_dir/Adwaita-blue" ] && { found_colors=1; break; }
    done
    echo "adwaita_colors=$found_colors"

    for check_dir in "$HOME/.local/share/icons/MoreWaita" "/usr/share/icons/MoreWaita" "/usr/local/share/icons/MoreWaita"; do
        [ -d "$check_dir" ] && { echo "morewaita=1"; break; }
    done || echo "morewaita=0"

    # Also check our Noctalia copies
    [ -d "$ICONS_USER/$PAPIRUS_THEME_NAME" ] && echo "papirus_installed=1" || echo "papirus_installed=0"
    [ -d "$ICONS_USER/$ADWAITA_THEME_NAME" ] && echo "adwaita_installed=1" || echo "adwaita_installed=0"
}
```

Add `--check-deps` to arg parsing:

```bash
            --check-deps) operation="check-deps" ;;
```

And dispatch:

```bash
        check-deps) do_check_deps ;;
```

**Step 4: Update usage text**

Add:

```
  $PROGNAME --install-dep <name>              Install upstream dependency
  $PROGNAME --check-deps                      Check all dependency status

DEPENDENCIES
  papirus-icon-theme    Papirus icon theme (for recolor mode)
  papirus-folders       Papirus folder color tool (for closest match)
  adwaita-colors        Adwaita color variants (for closest match)
  morewaita             MoreWaita icon extensions (optional)
```

**Step 5: Test**

Run: `noctalia-folders --check-deps`
Expected: Key=value output showing 0 or 1 for each dependency.

**Step 6: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: add --install-dep and --check-deps commands"
```

---

### Task 3: Bash script — add `papirus-match` mode

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders`

**Step 1: Add papirus-folders color presets to python helper**

In `read_and_derive()`, after the `elif mode == "adwaita-match":` block (line 151-164), add a new elif before `PYEOF`:

```python
elif mode == "papirus-match":
    # Find closest papirus-folders preset color
    presets = {
        "black": "#4f4f4f", "blue": "#5294e2", "bluegrey": "#607d8b",
        "breeze": "#4a8bca", "brown": "#ae8e6c", "carmine": "#b13d59",
        "cyan": "#00bcd4", "darkcyan": "#008394", "deeporange": "#ff5722",
        "green": "#87b158", "grey": "#8e8e8e", "indigo": "#5c6bc0",
        "magenta": "#ca71df", "nordic": "#5e81ac", "orange": "#ee923a",
        "palebrown": "#c4a882", "paleorange": "#f0c67b", "pink": "#f06292",
        "red": "#e93d40", "teal": "#009688", "violet": "#9b6bdf",
        "white": "#e4e4e4", "yaru": "#e35641",
    }
    target_rgb = tuple(int(x * 255) for x in colorsys.hls_to_rgb(h, l, s))
    best = min(presets.items(), key=lambda kv: dist(target_rgb, tuple(int(x*255) for x in hex_to_rgb(kv[1]))))
    print(best[0])
```

Note: the `dist()` function is already defined in the `adwaita-match` block. Move it above both match blocks so both can use it. Place it right after `if dim: h, s, l = dim_color(h, s, l)`:

```python
def dist(c1, c2):
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))
```

Then remove the duplicate from the adwaita-match block.

**Step 2: Update `read_and_derive()` mode handling**

In the python code, change `if mode == "papirus":` to `if mode == "papirus-recolor":` (line 133).

Also update `derive_restore_colors()` — change `if mode == "papirus":` to `if mode == "papirus-recolor":` (line 194).

**Step 3: Add papirus-match case to `do_apply()`**

In `do_apply()`, rename the `papirus)` case to `papirus-recolor)`. Then add a new case after it:

```bash
        papirus-match)
            local best_color
            best_color="$(echo "$result" | sed -n '3p')"

            msg "Applying $primary from '$scheme_name' (papirus-match, source: $COLOR_SOURCE) ..."
            msg "  Best match: $best_color"

            if ! command -v papirus-folders &>/dev/null; then
                fatal "papirus-folders is not installed. Run: noctalia-folders --install-dep papirus-folders"
            fi

            papirus-folders -C "$best_color" --theme Papirus-Dark
            save_state "$primary" "$scheme_name" "papirus-match" "$DIM_MODE"
            apply_icon_theme "Papirus-Dark"
            ;;
```

**Step 4: Update do_install, do_reset, revert_icon_theme**

In `do_install()`:

```bash
do_install() {
    case "$ICON_THEME" in
        papirus-recolor) do_install_papirus ;;
        papirus-match)   msg "Papirus match mode uses papirus-folders directly." ;;
        adwaita-recolor) do_install_adwaita ;;
        adwaita-match)   msg "Adwaita closest-match mode does not require installation." ;;
        *)               fatal "Unknown icon theme mode: $ICON_THEME" ;;
    esac
}
```

In `do_reset()`, add `papirus-match)` alongside `adwaita-match)`:

```bash
        papirus-match)
            msg "Resetting Papirus to default blue ..."
            if command -v papirus-folders &>/dev/null; then
                papirus-folders -C blue --theme Papirus-Dark
            fi
            ;;
```

In `revert_icon_theme()`:

```bash
revert_icon_theme() {
    local mode="${1:-papirus-recolor}"
    case "$mode" in
        papirus-recolor|papirus-match) apply_icon_theme "Papirus-Dark" ;;
        adwaita-match|adwaita-recolor) apply_icon_theme "Adwaita" ;;
        *)                             apply_icon_theme "Papirus-Dark" ;;
    esac
}
```

**Step 5: Update `apply_icon_theme()` case patterns**

In `apply_icon_theme()`, the base_theme case already uses `papirus*)` and `adwaita*)` patterns, so it handles `papirus-recolor` and `papirus-match` automatically. No change needed.

**Step 6: Update `do_restore_papirus_quietly()`**

Change the state file reference from `state.papirus` to `state.papirus-recolor`:

```bash
    local state_file="$CONFIG_DIR/state.papirus-recolor"
```

**Step 7: Update usage text and header comment**

Update the modes list:

```
  --icon-theme <mode>      papirus-recolor | papirus-match | adwaita-match | adwaita-recolor
```

Update header comment:

```bash
# Supports four modes:
#   papirus-recolor - Recolor Papirus-Dark folder SVGs (default)
#   papirus-match   - Use papirus-folders closest preset color
#   adwaita-match   - Switch to closest built-in Adwaita-{color} theme
#   adwaita-recolor - Recolor Adwaita folder SVGs with exact accent
```

**Step 8: Update default ICON_THEME**

Change line 740:

```bash
ICON_THEME="papirus-recolor"
```

**Step 9: Test**

Run: `noctalia-folders --apply --icon-theme papirus-recolor --verbose`
Expected: Recolors SVGs as before.

Run: `noctalia-folders --apply --icon-theme papirus-match --verbose`
Expected: Calls papirus-folders with nearest color preset (or fails gracefully if not installed).

**Step 10: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: add papirus-match mode using papirus-folders presets"
```

---

### Task 4: Main.qml — add enabled property, expanded dep checks, IPC

**Files:**
- Modify: `noctalia-folders/Main.qml`

**Step 1: Add new properties**

After `property bool installCheckDone: false` (line 25), add:

```qml
    // Dependency status (upstream)
    property bool papirusIconThemeAvailable: false
    property bool papirusFoldersAvailable: false
    property bool adwaitaBaseAvailable: false
    property bool adwaitaColorsAvailable: false
    property bool morewaitaAvailable: false
```

After `readonly property bool debugMode:` (line 32), add:

```qml
    readonly property bool enabled: pluginApi?.pluginSettings?.enabled ?? false
    readonly property bool setGtkTheme: pluginApi?.pluginSettings?.setGtkTheme ?? true
    readonly property bool setQtTheme: pluginApi?.pluginSettings?.setQtTheme ?? true
```

**Step 2: Gate auto-apply on enabled**

In `_autoApplyIfChanged()` (line 83-88), add enabled check:

```qml
    function _autoApplyIfChanged(reason) {
        if (root.enabled && root.autoApply && !root.isRunning && root._currentFingerprint() !== root.lastAppliedFingerprint) {
            Logger.i("NoctaliaFolders", reason)
            root.applyFolders()
        }
    }
```

In `Component.onCompleted` (line 97-101), gate startup on enabled:

```qml
    Component.onCompleted: {
        root.checkInstallStatus()
        if (root.enabled) {
            stateCheckProcess.running = true
            startupTimer.running = true
        }
    }
```

**Step 3: Update buildCmd to pass GTK/QT flags**

In `buildCmd()` (line 50-58), add flags:

```qml
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
```

**Step 4: Add IPC enable/disable commands**

In the IpcHandler (line 148-166), add:

```qml
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
```

**Step 5: Replace installCheckProcess with expanded dep check**

Replace the `installCheckProcess` command (line 296-325) with:

```qml
    Process {
        id: installCheckProcess
        command: ["sh", "-c", `"${root.scriptPath}" --check-deps`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const [key, val] = line.split("=")
                    if (key === "papirus_icon_theme") root.papirusIconThemeAvailable = val === "1"
                    if (key === "papirus_folders") root.papirusFoldersAvailable = val === "1"
                    if (key === "adwaita_base") root.adwaitaBaseAvailable = val === "1"
                    if (key === "adwaita_colors") root.adwaitaColorsAvailable = val === "1"
                    if (key === "morewaita") root.morewaitaAvailable = val === "1"
                    if (key === "papirus_installed") root.papirusInstalled = val === "1"
                    if (key === "adwaita_installed") root.adwaitaInstalled = val === "1"
                }
                root.installCheckDone = true
                Logger.i("NoctaliaFolders", `Dep check: papirus-icon-theme=${root.papirusIconThemeAvailable}, papirus-folders=${root.papirusFoldersAvailable}, adwaita=${root.adwaitaBaseAvailable}, adwaita-colors=${root.adwaitaColorsAvailable}, morewaita=${root.morewaitaAvailable}`)
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
```

**Step 6: Remove papirusSourceAvailable/adwaitaSourceAvailable**

Remove lines 23-24 (`property bool papirusSourceAvailable: false` and `property bool adwaitaSourceAvailable: false`). These are replaced by the more granular dependency properties.

**Step 7: Test**

Run from CLI: `qs ipc call plugin:noctalia-folders enable` (or however Quickshell IPC works)
Expected: Plugin enables, checks deps, starts auto-apply.

**Step 8: Commit**

```bash
git add noctalia-folders/Main.qml
git commit -m "feat: add enabled gate, expanded dep checks, GTK/QT flags, IPC enable/disable"
```

---

### Task 5: Settings.qml — enable switch and appearance updates

**Files:**
- Modify: `noctalia-folders/Settings.qml`

**Step 1: Add new edit properties**

After `property bool editDimMode:` (line 29-32), add:

```qml
    property bool editEnabled:
        pluginApi?.pluginSettings?.enabled ??
        pluginApi?.manifest?.metadata?.defaultSettings?.enabled ??
        false

    property bool editSetGtkTheme:
        pluginApi?.pluginSettings?.setGtkTheme ??
        pluginApi?.manifest?.metadata?.defaultSettings?.setGtkTheme ??
        true

    property bool editSetQtTheme:
        pluginApi?.pluginSettings?.setQtTheme ??
        pluginApi?.manifest?.metadata?.defaultSettings?.setQtTheme ??
        true
```

**Step 2: Update computeIconTheme and editBaseTheme/editMethod**

Update `editBaseTheme` and `editMethod`:

```qml
    readonly property string editBaseTheme: editIconTheme.startsWith("adwaita") ? "adwaita" : "papirus"
    readonly property string editMethod: editIconTheme.endsWith("-match") ? "match" : "recolor"
```

Update `computeIconTheme`:

```qml
    function computeIconTheme(baseTheme, method) {
        return baseTheme + "-" + method
    }
```

Update `editIconTheme` default to handle new mode names:

```qml
    property string editIconTheme:
        pluginApi?.pluginSettings?.iconTheme ||
        pluginApi?.manifest?.metadata?.defaultSettings?.iconTheme ||
        "papirus-recolor"
```

**Step 3: Add the enable switch NBox**

Insert before the Appearance NBox (before line 58):

```qml
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
```

**Step 4: Gate all sections on enabled**

Wrap each of the remaining NBox sections (Appearance, Dependency Status, Behavior, Advanced) with:

```qml
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4
```

Add these two lines as properties on each NBox after `color: Color.mSurfaceVariant`.

**Step 5: Update Appearance section**

Update the Method combo to always be enabled (remove the Item wrapper with the adwaita-only gate):

Replace lines 117-137 (the Item wrapper + NComboBox) with just:

```qml
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
```

Update the warning text (lines 98-115) to check the right dependency based on both base theme AND method:

```qml
            NText {
                visible: {
                    const mi = pluginApi?.mainInstance
                    if (!mi?.installCheckDone) return false
                    if (root.editBaseTheme === "papirus") {
                        if (root.editMethod === "recolor" && !mi.papirusIconThemeAvailable) return true
                        if (root.editMethod === "match" && !mi.papirusFoldersAvailable) return true
                    }
                    if (root.editBaseTheme === "adwaita") {
                        if (root.editMethod === "recolor" && !mi.adwaitaBaseAvailable) return true
                        if (root.editMethod === "match" && !mi.adwaitaColorsAvailable) return true
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
```

**Step 6: Test**

Verify in settings UI: enable switch toggles all sections disabled/enabled. Method combo available for both Papirus and Adwaita.

**Step 7: Commit**

```bash
git add noctalia-folders/Settings.qml
git commit -m "feat: add enable switch, update appearance for 4 modes"
```

---

### Task 6: Settings.qml — dependency status section

**Files:**
- Modify: `noctalia-folders/Settings.qml`

**Step 1: Replace the Icon Theme Status section**

Replace the entire "Icon Theme Status" NBox (lines 150-267) with the new Dependency Status section:

```qml
    // ──────────────────────────────────────────────
    // Dependency Status
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: depContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        ColumnLayout {
            id: depContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
                text: "Dependency Status"
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
            }

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
                        if (mi.papirusIconThemeAvailable) return "#4caf50"
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
                        return mi.papirusIconThemeAvailable ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
                Item { Layout.fillWidth: true }
                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.papirusIconThemeAvailable
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
                        if (mi.papirusFoldersAvailable) return "#4caf50"
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
                        return mi.papirusFoldersAvailable ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
                Item { Layout.fillWidth: true }
                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.papirusFoldersAvailable
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
                        if (mi.adwaitaBaseAvailable) return "#4caf50"
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
                        return mi.adwaitaBaseAvailable ? "Installed" : "Not installed"
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
                        if (mi.adwaitaColorsAvailable) return "#4caf50"
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
                        return mi.adwaitaColorsAvailable ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
                Item { Layout.fillWidth: true }
                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.adwaitaColorsAvailable
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
                        if (mi.morewaitaAvailable) return "#4caf50"
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
                        return mi.morewaitaAvailable ? "Installed" : "Not installed"
                    }
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
                Item { Layout.fillWidth: true }
                NButton {
                    text: "Install"
                    visible: {
                        const mi = pluginApi?.mainInstance
                        return mi?.installCheckDone && !mi.morewaitaAvailable
                    }
                    onClicked: root.launchInstallDep("morewaita")
                }
            }
        }
    }
```

**Step 2: Add `launchInstallDep` function**

Replace the existing `launchInstall()` function (lines 376-383) with:

```qml
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
```

**Step 3: Test**

Verify in settings UI: Dependency Status shows 5 items split into Papirus/Adwaita sections. Dot colors match the current mode selection. Install buttons appear for missing deps.

**Step 4: Commit**

```bash
git add noctalia-folders/Settings.qml
git commit -m "feat: dependency status section with 5 upstream checks"
```

---

### Task 7: Settings.qml — collapsible Behavior and Advanced sections

**Files:**
- Modify: `noctalia-folders/Settings.qml`

**Step 1: Add expanded state properties**

After the edit properties (near the top of the root ColumnLayout), add:

```qml
    property bool behaviorExpanded: false
    property bool advancedExpanded: false
```

**Step 2: Replace Behavior section with collapsible version**

Replace the entire Behavior NBox (lines 269-300) with:

```qml
    // ──────────────────────────────────────────────
    // Behavior (collapsible)
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: behaviorHeader.implicitHeight + (root.behaviorExpanded ? behaviorBody.implicitHeight + Style.marginS : 0) + Style.marginM * 2
        color: Color.mSurfaceVariant
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
                id: behaviorHeader
                spacing: Style.marginS

                NText {
                    text: root.behaviorExpanded ? "\u25BE" : "\u25B8"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                }

                NText {
                    text: "Behavior"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                }

                Item { Layout.fillWidth: true }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.behaviorExpanded = !root.behaviorExpanded
                }
            }

            ColumnLayout {
                id: behaviorBody
                visible: root.behaviorExpanded
                spacing: Style.marginS

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
        }
    }
```

**Step 3: Replace Advanced section with collapsible version**

Replace the entire Advanced NBox (lines 302-347) with:

```qml
    // ──────────────────────────────────────────────
    // Advanced (collapsible)
    // ──────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: advancedHeader.implicitHeight + (root.advancedExpanded ? advancedBody.implicitHeight + Style.marginS : 0) + Style.marginM * 2
        color: Color.mSurfaceVariant
        enabled: root.editEnabled
        opacity: enabled ? 1.0 : 0.4

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
                id: advancedHeader
                spacing: Style.marginS

                NText {
                    text: root.advancedExpanded ? "\u25BE" : "\u25B8"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurface
                }

                NText {
                    text: "Advanced"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                }

                Item { Layout.fillWidth: true }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.advancedExpanded = !root.advancedExpanded
                }
            }

            ColumnLayout {
                id: advancedBody
                visible: root.advancedExpanded
                spacing: Style.marginS

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
        }
    }
```

**Step 4: Test**

Verify: clicking Behavior/Advanced headers toggles content visibility. Arrow indicator changes direction.

**Step 5: Commit**

```bash
git add noctalia-folders/Settings.qml
git commit -m "feat: collapsible Behavior and Advanced sections"
```

---

### Task 8: Settings.qml — update saveSettings and Main.qml enable/disable logic

**Files:**
- Modify: `noctalia-folders/Settings.qml`
- Modify: `noctalia-folders/Main.qml`

**Step 1: Update saveSettings() in Settings.qml**

Replace the `saveSettings()` function (lines 385-405) with:

```qml
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
            // Trigger recolor with explicit values
            pluginApi?.mainInstance?.applyFolders(root.editIconTheme, sourceKey, root.editDimMode)
        } else if (wasEnabled) {
            // Was enabled, now disabled — reset folders
            pluginApi?.mainInstance?.resetFolders()
        }

        Logger.i("NoctaliaFolders", "Settings saved successfully")
    }
```

**Step 2: Update Main.qml applyFolders to check enabled**

In `applyFolders()` (line 172-177), add enabled check:

```qml
    function applyFolders(overrideIconTheme, overrideAccentSource, overrideDimMode) {
        if (!root.enabled || root.isRunning) return
        root.isRunning = true
        applyProcess.command = ["sh", "-c", root.buildCmd("--apply", overrideIconTheme, overrideAccentSource, overrideDimMode)]
        applyProcess.running = true
    }
```

**Step 3: Test**

Verify: Save with enabled=true triggers apply. Save with enabled=false triggers reset. Toggling enabled off then saving restores default icons.

**Step 4: Commit**

```bash
git add noctalia-folders/Settings.qml noctalia-folders/Main.qml
git commit -m "feat: saveSettings handles enable/disable transitions"
```

---

### Task 9: Update manifest.json with new defaults

**Files:**
- Modify: `noctalia-folders/manifest.json`

**Step 1: Update defaultSettings**

Replace the `defaultSettings` object:

```json
    "defaultSettings": {
      "enabled": false,
      "autoApply": true,
      "iconTheme": "papirus-recolor",
      "dimMode": false,
      "accentSource": "mPrimary",
      "debugMode": false,
      "setGtkTheme": true,
      "setQtTheme": true
    }
```

**Step 2: Bump version**

Change version to `"3.0.0"` (breaking change — new mode names, new enabled property).

Also update `VERSION` in the bash script to match:

```bash
readonly VERSION="3.0.0"
```

**Step 3: Test**

Verify plugin loads with fresh settings (delete existing plugin settings to test defaults).

**Step 4: Commit**

```bash
git add noctalia-folders/manifest.json noctalia-folders/scripts/noctalia-folders
git commit -m "feat: update manifest defaults for v3.0.0"
```

---

### Task 10: Integration testing and cleanup

**Step 1: Test enable/disable cycle**

1. Open settings, enable plugin, save -> should check deps and apply
2. Change accent source, save -> should recolor
3. Disable plugin, save -> should restore default icons
4. Verify all sections are dimmed when disabled

**Step 2: Test all 4 modes**

1. Papirus Recolor: `noctalia-folders --apply --icon-theme papirus-recolor --verbose`
2. Papirus Match: `noctalia-folders --apply --icon-theme papirus-match --verbose`
3. Adwaita Recolor: `noctalia-folders --apply --icon-theme adwaita-recolor --verbose`
4. Adwaita Match: `noctalia-folders --apply --icon-theme adwaita-match --verbose`

**Step 3: Test dependency installation**

1. `noctalia-folders --install-dep morewaita` -> installs MoreWaita
2. `noctalia-folders --check-deps` -> shows updated status

**Step 4: Test GTK/QT flag behavior**

1. `noctalia-folders --apply --no-set-gtk --verbose` -> no GTK messages
2. `noctalia-folders --apply --no-set-qt --verbose` -> no QT messages

**Step 5: Test IPC**

1. IPC enable when disabled -> enables and applies
2. IPC disable when enabled -> resets and disables

**Step 6: Final commit**

```bash
git add -A
git commit -m "chore: integration testing cleanup"
```
