# Noctalia Folders Bug Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 6 bugs in the noctalia-folders plugin: broken icons, missing notifications, tooltip flickering, redundant button, square swatches, and broken dim mode.

**Architecture:** All changes are in 3 files: `scripts/noctalia-folders` (bash), `Main.qml` (QML), and `Settings.qml` (QML). The bash script generates an `index.theme` that needs to be fixed for proper icon fallback. The QML files need toast notifications, layout fixes, and property change handlers.

**Tech Stack:** QML/QtQuick (Quickshell framework), Bash, freedesktop icon theme spec

---

### Task 1: Fix broken icons — Papirus index.theme

**Files:**
- Modify: `scripts/noctalia-folders:248-273`

**Step 1: Replace the Papirus index.theme generation**

In `do_install_papirus()`, replace the heredoc + grep block (lines 248-273). The current code writes a header then blindly copies ALL directory declarations from Papirus-Dark. Replace with a self-contained index.theme that only declares the `places/` directories we actually populate, and includes the required `Directories=` key.

Replace this block (lines 248-273):
```bash
    cat > "$theme_dir/index.theme" << 'INDEXEOF'
[Icon Theme]
Name=Papirus-Noctalia
Comment=Papirus-Dark with Noctalia accent-colored folders
Inherits=Papirus-Dark,Papirus,breeze-dark,hicolor

Example=folder
FollowsColorScheme=true

DesktopDefault=48
DesktopSizes=16,22,24,32,48,64
ToolbarDefault=22
ToolbarSizes=16,22,24,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,24,32,48
SmallDefault=16
SmallSizes=16,22,24,32,48
PanelDefault=48
PanelSizes=16,22,24,32,48,64
DialogDefault=48
DialogSizes=16,22,24,32,48,64

INDEXEOF

    grep -E '^\[|^Size=|^Context=|^MinSize=|^MaxSize=|^Type=' \
        "$source_dir/index.theme" >> "$theme_dir/index.theme" 2>/dev/null || true
```

With this (generates `Directories=` dynamically from `PAPIRUS_SIZES` and only declares `places/` contexts):
```bash
    # Build Directories= line from sizes we'll actually populate
    local dir_list=""
    for size in "${PAPIRUS_SIZES[@]}"; do
        [ -n "$dir_list" ] && dir_list+=","
        dir_list+="${size}/places"
    done

    cat > "$theme_dir/index.theme" << INDEXEOF
[Icon Theme]
Name=Papirus-Noctalia
Comment=Papirus-Dark with Noctalia accent-colored folders
Inherits=Papirus-Dark,Papirus,breeze-dark,hicolor

Example=folder
FollowsColorScheme=true

Directories=${dir_list}

INDEXEOF

    # Add a [size/places] section for each size
    for size in "${PAPIRUS_SIZES[@]}"; do
        local num="${size%%x*}"
        cat >> "$theme_dir/index.theme" << SECTIONEOF
[${size}/places]
Context=Places
Size=${num}
Type=Fixed

SECTIONEOF
    done
```

Note: The heredoc delimiter changes from `'INDEXEOF'` (literal) to `INDEXEOF` (expanding) so that `${dir_list}` and `${size}` are interpolated.

**Step 2: Verify the fix**

Run: `bash scripts/noctalia-folders --install --icon-theme papirus`

Then check the generated index.theme:
```bash
cat ~/.local/share/icons/Papirus-Noctalia/index.theme
```

Expected: Should contain `Directories=22x22/places,24x24/places,32x32/places,48x48/places,64x64/places` and only `[NNxNN/places]` sections — NO `[NNxNN/actions]`, `[NNxNN/apps]`, etc.

**Step 3: Commit**

```bash
git add scripts/noctalia-folders
git commit -m "fix: generate correct Papirus index.theme with Directories= key

Only declare places/ directories we actually populate. Adds the required
Directories= key per freedesktop icon theme spec. Fixes broken fallback
for non-folder icons (trash, starred, etc.)."
```

---

### Task 2: Fix broken icons — Adwaita index.theme

**Files:**
- Modify: `scripts/noctalia-folders:319-344`

**Step 1: Replace the Adwaita index.theme generation**

In `do_install_adwaita()`, replace the heredoc + grep block (lines 319-344). Same problem as Papirus — blindly copies all sections. For Adwaita we have `scalable/places` plus optional raster sizes.

Replace this block (lines 319-344):
```bash
    cat > "$theme_dir/index.theme" << 'INDEXEOF'
[Icon Theme]
Name=Adwaita-Noctalia
Comment=Adwaita with Noctalia accent-colored folders
Inherits=Adwaita,AdwaitaLegacy,hicolor

Example=folder
FollowsColorScheme=true

DesktopDefault=48
DesktopSizes=16,22,24,32,48,64,96
ToolbarDefault=22
ToolbarSizes=16,22,24,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,24,32,48
SmallDefault=16
SmallSizes=16,22,24,32,48
PanelDefault=48
PanelSizes=16,22,24,32,48,64
DialogDefault=48
DialogSizes=16,22,24,32,48,64,96

INDEXEOF

    grep -E '^\[|^Size=|^Context=|^MinSize=|^MaxSize=|^Type=' \
        "$source_dir/index.theme" >> "$theme_dir/index.theme" 2>/dev/null || true
```

With:
```bash
    # Build Directories= line: scalable/places + any raster sizes that exist
    local dir_list="scalable/places"
    local raster_size
    for raster_size in 16x16 22x22 24x24 32x32 48x48 64x64 96x96; do
        [ -d "$source_dir/$raster_size/places" ] && dir_list+=",${raster_size}/places"
    done

    cat > "$theme_dir/index.theme" << INDEXEOF
[Icon Theme]
Name=Adwaita-Noctalia
Comment=Adwaita with Noctalia accent-colored folders
Inherits=Adwaita,AdwaitaLegacy,hicolor

Example=folder
FollowsColorScheme=true

Directories=${dir_list}

[scalable/places]
Context=Places
Size=64
MinSize=16
MaxSize=512
Type=Scalable

INDEXEOF

    for raster_size in 16x16 22x22 24x24 32x32 48x48 64x64 96x96; do
        [ -d "$source_dir/$raster_size/places" ] || continue
        local num="${raster_size%%x*}"
        cat >> "$theme_dir/index.theme" << SECTIONEOF
[${raster_size}/places]
Context=Places
Size=${num}
Type=Fixed

SECTIONEOF
    done
```

**Step 2: Verify the fix**

Run: `bash scripts/noctalia-folders --install --icon-theme adwaita-recolor`

Then check:
```bash
cat ~/.local/share/icons/Adwaita-Noctalia/index.theme
```

Expected: Should contain `Directories=scalable/places,...` and only `[.../places]` sections.

**Step 3: Commit**

```bash
git add scripts/noctalia-folders
git commit -m "fix: generate correct Adwaita index.theme with Directories= key"
```

---

### Task 3: Add toast notifications to Main.qml

**Files:**
- Modify: `Main.qml:1-5` (imports)
- Modify: `Main.qml:126-131` (applyFolders function)
- Modify: `Main.qml:168-176` (applyProcess.onExited)
- Modify: `Main.qml:187-195` (resetProcess.onExited)
- Modify: `Main.qml:226-236` (installProcess.onExited)

**Step 1: Add import**

Add `import qs.Services.UI` after line 4 (`import qs.Commons`):
```qml
import qs.Services.UI
```

**Step 2: Add toast to applyFolders()**

In `applyFolders()` (line 126-131), add a toast after setting `isRunning`:
```qml
    function applyFolders() {
        if (root.isRunning) return
        root.isRunning = true
        ToastService.showNotice("Noctalia Folders", "Recoloring folder icons...", "folder")
        applyProcess.command = ["sh", "-c", root.buildCmd("--apply")]
        applyProcess.running = true
    }
```

**Step 3: Add toasts to applyProcess.onExited**

Replace lines 168-176:
```qml
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
```

**Step 4: Add toasts to resetProcess.onExited**

Replace lines 187-195:
```qml
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
```

**Step 5: Add toasts to installProcess.onExited**

Replace lines 226-236:
```qml
        onExited: function(exitCode) {
            root.isRunning = false
            if (exitCode === 0) {
                Logger.i("NoctaliaFolders", "Icon theme installed successfully")
                ToastService.showNotice("Noctalia Folders", "Icon theme installed!", "folder")
                if (root.autoApply) {
                    root.applyFolders()
                }
            } else {
                Logger.e("NoctaliaFolders", `Install failed with exit code ${exitCode}`)
                ToastService.showError("Noctalia Folders", "Failed to install icon theme")
            }
        }
```

**Step 6: Commit**

```bash
git add Main.qml
git commit -m "feat: add toast notifications for apply/reset/install operations

Uses ToastService.showNotice() on start and success, showError() on failure.
Gives users visible feedback instead of only Logger output."
```

---

### Task 4: Add spinner state to Settings.qml

**Files:**
- Modify: `Settings.qml:209-220` (status section)

**Step 1: Add busy indicator above the Status label**

Insert a running indicator before the Status NLabel (before line 209). Add it right after the NDivider on line 203:

After the `NDivider` at line 201-203 and before the Status NLabel at line 209, insert:
```qml
    NLabel {
        visible: pluginApi?.mainInstance?.isRunning ?? false
        label: "Recoloring..."
        description: "Folder icons are being recolored. This may take a moment."
    }
```

**Step 2: Commit**

```bash
git add Settings.qml
git commit -m "feat: add visual busy indicator when recoloring is in progress"
```

---

### Task 5: Fix tooltip flickering — static Repeater model

**Files:**
- Modify: `Settings.qml:7-36` (properties section)
- Modify: `Settings.qml:68-113` (color swatch Repeater)

**Step 1: Add cached color properties**

After the existing `editScriptPath` property (line 33-36), add a helper function:
```qml
    function colorForKey(key) {
        switch (key) {
        case "mPrimary":   return Color.mPrimary || "#888888"
        case "mSecondary": return Color.mSecondary || "#888888"
        case "mTertiary":  return Color.mTertiary || "#888888"
        case "mHover":     return Color.mHover || "#888888"
        default:           return "#888888"
        }
    }
```

**Step 2: Make the Repeater model static**

Replace the Repeater model (lines 73-79) — remove Color refs from the model array:
```qml
        Repeater {
            model: [
                { key: "mPrimary",   label: "P" },
                { key: "mSecondary", label: "S" },
                { key: "mTertiary",  label: "T" },
                { key: "mHover",     label: "H" }
            ]
```

**Step 3: Update delegate to use helper function**

Replace line 88 (`color: modelData.color || "#888888"`) with:
```qml
                    color: root.colorForKey(modelData.key)
```

**Step 4: Commit**

```bash
git add Settings.qml
git commit -m "fix: prevent tooltip flickering from Repeater model bindings

Move Color property lookups out of the Repeater model array into a
helper function. The static model prevents Repeater from reconstructing
delegates on every Color property change, which was causing layout
thrashing that interfered with tooltip positioning."
```

---

### Task 6: Remove redundant Apply Now button + round swatches

**Files:**
- Modify: `Settings.qml:84-87` (swatch radius)
- Modify: `Settings.qml:230-238` (Apply Now button)

**Step 1: Make swatches circular**

Change line 87 from:
```qml
                    radius: 6
```
To:
```qml
                    radius: width / 2
```

**Step 2: Remove Apply Now button**

Remove the entire Apply Now NButton block (lines 233-238):
```qml
        NButton {
            text: "Apply Now"
            onClicked: {
                pluginApi?.mainInstance?.applyFolders()
            }
        }
```

**Step 3: Commit**

```bash
git add Settings.qml
git commit -m "fix: round color swatches + remove redundant Apply Now button

Change swatch radius from 6 to width/2 for circular shape matching
Noctalia conventions. Remove Apply Now button since the framework
settings window already provides an Apply button."
```

---

### Task 7: Fix dim mode and icon theme change handlers

**Files:**
- Modify: `Main.qml:74-80` (after onAccentSourceChanged)

**Step 1: Add onDimModeChanged and onIconThemeChanged handlers**

After the `onAccentSourceChanged` block (line 75-80), add two new handlers:
```qml
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
```

These fire when `pluginSettings.dimMode` or `pluginSettings.iconTheme` changes (after the framework calls `saveSettings()`), triggering a re-apply with the new setting.

**Step 2: Commit**

```bash
git add Main.qml
git commit -m "fix: trigger re-apply when dim mode or icon theme changes

Add onDimModeChanged and onIconThemeChanged handlers so that changing
these settings and pressing Apply actually recolors the folders with
the new configuration."
```

---

### Task 8: Reinstall and verify all fixes

**Step 1: Reinstall the icon theme**

```bash
bash scripts/noctalia-folders --install --icon-theme papirus
```

**Step 2: Check index.theme is correct**

```bash
head -20 ~/.local/share/icons/Papirus-Noctalia/index.theme
```

Expected: `Directories=22x22/places,...` present, no non-places sections.

**Step 3: Apply and verify non-folder icons work**

```bash
bash scripts/noctalia-folders --apply --icon-theme papirus
```

Open a file manager — trash, starred, and bookmark icons should display correctly from the Papirus-Dark fallback.

**Step 4: Commit all remaining changes**

If any files were missed, commit them now.
