# Noctalia Folders Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix icon refresh visibility, remove redundant settings buttons, add graceful degradation for missing base themes.

**Architecture:** Three independent fixes to the bash script and Settings.qml. The bash script gets a theme-toggle trick to force GTK refresh. Settings.qml drops custom buttons and follows the official plugin pattern. Install status feeds graceful degradation warnings.

**Tech Stack:** QML (Quickshell), Bash, gsettings

---

### Task 1: Force GTK icon refresh in bash script

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders:636-670` (apply_icon_theme function)

**Step 1: Add theme toggle to force GTK refresh**

In `apply_icon_theme()`, after setting all the config files, add a toggle that briefly switches to the base theme and back. This forces GTK to invalidate its icon cache.

Replace the gsettings block (lines 638-640) with:

```bash
apply_icon_theme() {
    local theme="$1"

    # Determine base theme for toggle trick
    local base_theme="hicolor"
    case "$ICON_THEME" in
        papirus*)        base_theme="$PAPIRUS_BASE_THEME" ;;
        adwaita*)        base_theme="$ADWAITA_BASE_THEME" ;;
    esac

    # Force GTK to re-read icons by toggling theme away and back
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$base_theme" 2>/dev/null
        sleep 0.2
        gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null
        msg "Set GNOME/GTK -> $theme (refreshed)"
    fi

    # ... rest of function unchanged (gtk3, gtk4, kde, qt5ct, qt6ct) ...
```

**Step 2: Test manually**

Run: `./noctalia-folders/scripts/noctalia-folders --apply`
Expected: Folders visually update in file manager after apply completes.

**Step 3: Commit**

```
git add noctalia-folders/scripts/noctalia-folders
git commit -m "fix: force GTK icon refresh by toggling theme after recolor"
```

---

### Task 2: Remove redundant Apply/Reset buttons from Settings.qml

**Files:**
- Modify: `noctalia-folders/Settings.qml:309-337` (remove bottom action buttons)
- Modify: `noctalia-folders/Settings.qml:298-306` (add Reset button to Advanced section)
- Modify: `noctalia-folders/Settings.qml:375-389` (update saveSettings to trigger recolor)

**Step 1: Remove the bottom RowLayout (lines 309-337)**

Delete the entire block:
```qml
    // ──────────────────────────────────────────────
    // Bottom action buttons
    // ──────────────────────────────────────────────

    RowLayout { ... }

    Item {
        Layout.fillHeight: true
    }
```

**Step 2: Add Reset button to Advanced section**

After the "Rebuild Icon Cache" button (line 305), add:

```qml
            NButton {
                text: "Reset to Default Icons"
                onClicked: {
                    pluginApi?.mainInstance?.resetFolders()
                }
            }
```

**Step 3: Update saveSettings() to trigger recolor**

Update the `saveSettings()` function to also trigger recoloring after saving:

```qml
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
```

**Step 4: Commit**

```
git add noctalia-folders/Settings.qml
git commit -m "fix: remove redundant Apply/Reset buttons, use shell's Save pattern"
```

---

### Task 3: Graceful degradation for missing base themes

**Files:**
- Modify: `noctalia-folders/Settings.qml:80-91` (icon theme combo)
- Modify: `noctalia-folders/Main.qml:290-319` (installCheckProcess - add ipirus check)

**Step 1: Expose source availability in installCheckProcess**

The installCheckProcess already checks `papirus_source` and `adwaita_source`. These are already exposed as `papirusSourceAvailable` and `adwaitaSourceAvailable` on Main.qml. No change needed in Main.qml.

**Step 2: Add warning text below icon theme combo in Settings.qml**

After the NComboBox for icon theme (after line 91), add:

```qml
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
```

**Step 3: Commit**

```
git add noctalia-folders/Settings.qml
git commit -m "feat: show warning when base icon theme is not installed"
```

---

### Task 4: Push and test

**Step 1: Push all changes**

```
git push
```

**Step 2: Update plugin in Noctalia shell and verify**

- Folder icons visually refresh after applying
- Settings panel has no Apply/Reset buttons at bottom
- Shell Save button saves settings and triggers recolor
- Warning appears if base theme is missing (test by temporarily checking with a fake theme name)
