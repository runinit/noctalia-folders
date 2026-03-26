# Noctalia Folders - Fixes Design

## Problems

1. **Recoloring not visible**: Script recolors SVGs correctly but GTK caches old icon renders. Setting icon-theme to the same value via gsettings doesn't trigger a refresh.

2. **Redundant Apply/Reset buttons**: Settings.qml has custom Apply and Reset buttons. The shell already provides Save/Cancel and calls `saveSettings()` automatically.

3. **Missing graceful degradation**: If base icon themes (Papirus-Dark, Adwaita) aren't installed, plugin should warn rather than fail silently.

## Solutions

### 1. Force GTK icon refresh after recoloring

In the bash script's `apply_icon_theme()` function, toggle the icon theme away and back to force GTK to re-read changed SVGs:

```bash
gsettings set org.gnome.desktop.interface icon-theme "$BASE_THEME"
sleep 0.1
gsettings set org.gnome.desktop.interface icon-theme "$theme"
```

The base theme is the parent theme (Papirus-Dark for papirus mode, Adwaita for adwaita modes). This causes GTK to invalidate its icon cache and re-render from the updated SVGs.

### 2. Settings.qml: remove redundant buttons, follow official pattern

- Remove bottom RowLayout with Apply/Reset buttons
- Move "Reset to Default" button into the Advanced section
- In `saveSettings()`, after persisting settings, trigger recoloring via `pluginApi.mainInstance.applyFolders()`
- This way: shell Save button -> `saveSettings()` -> saves settings AND recolors

### 3. Graceful degradation for missing base themes

- The install check already detects `papirusSourceAvailable` and `adwaitaSourceAvailable`
- In Settings.qml, disable the icon theme combo option when its base isn't available
- Show inline warning text when the selected base theme is missing
- The bash script already fatals with a clear message if the base theme is missing; no change needed there
