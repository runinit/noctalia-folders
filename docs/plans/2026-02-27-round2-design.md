# Noctalia Folders Plugin - Round 2 Refinements Design

Date: 2026-02-27

## Context

Round 1 fixed broken icons, added notifications, round swatches, removed Apply Now button. Testing revealed: tooltip flickering NOT fixed, dim mode still broken, UX needs simplification.

## 1. Fix Tooltip Flickering (Real Fix)

**Root cause:** Settings.qml is always instantiated by the Noctalia settings panel (inner Loader has `active: true`) even when our tab isn't active. NLabel `description` bindings directly reference `Color.mPrimary` etc., converting them to text strings. Every Color property change re-evaluates these strings, changing NLabel height, triggering NScrollView contentHeight recalculation, which propagates layout shifts to the sidebar causing tooltip flickering.

**Fix:** Remove ALL `Color.*` references from NLabel description bindings. The "Selected accent" NLabel and "Status" NLabel both have these. Redesigning the UI eliminates them naturally.

**Files:** `Settings.qml`

## 2. Simplify Notifications

Remove the "starting" toast from `applyFolders()`. Keep only completion toast on success and error toast on failure. The operation is fast enough that a "starting" notification is noise.

**Files:** `Main.qml`

## 3. Instant Apply on Swatch Click + Dim Toggle

**Problem:** Settings.qml edits local `edit*` properties. Main.qml reads from `pluginSettings.*` which only updates after framework `saveSettings()`. User wants instant recolor when clicking a swatch or toggling dim.

**Fix:** Add `applyWithOverrides(accentSource, dimMode)` function to Main.qml that builds a one-shot command with the given parameters instead of reading from pluginSettings. Settings.qml calls this directly on swatch click and dim toggle. The framework Apply button still calls `saveSettings()` to persist settings to disk.

**Files:** `Main.qml`, `Settings.qml`

## 4. Remove Script Override Setting

Remove from Settings.qml: `editScriptPath` property, NTextInput, its NDivider, and the `saveSettings()` line for scriptPath. Main.qml's `scriptPath` property stays (resolves bundled path). Remove `scriptPath` from `manifest.json` defaultSettings.

**Files:** `Settings.qml`, `manifest.json`

## 5. Merge Combo Box with Swatches

Remove the NComboBox for accent source. The round swatches become the sole selector with full labels underneath (Primary, Secondary, Tertiary, Hover instead of P, S, T, H). Clicking one selects it. Selected swatch gets a thick border. Remove the "Selected accent" NLabel too (redundant when swatches show the color visually).

**Files:** `Settings.qml`

## 6. Dim Mode Preview in Swatches

When dim mode is toggled on, swatch colors show the dimmed versions. Add a QML helper function that applies the same HSL math as the bash script (saturation * 0.70, lightness * 0.85) to compute dimmed colors for display.

**Files:** `Settings.qml`

## 7. Improved Status Section with Install Detection

On settings load, check if theme directories exist (`~/.local/share/icons/Papirus-Noctalia`, `~/.local/share/icons/Adwaita-Noctalia`, and system Papirus-Dark/Adwaita source dirs). Show install status for each. When the selected icon theme mode requires an uninstalled theme, show a warning + Install button. The icon theme mode NComboBox options should indicate which are available.

**Files:** `Settings.qml`, `Main.qml` (status check process)

## 8. Clean Up Status Display

Replace the current Status NLabel (which has Color.* bindings causing flickering) with a simpler status that shows:
- Current icon theme mode
- Last applied color (static string, no Color.* binding)
- Recoloring indicator when running

No live Color.* references in any NLabel description.

**Files:** `Settings.qml`
