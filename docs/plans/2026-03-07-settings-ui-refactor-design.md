# Settings UI Refactor - Design

## Overview

Refactor the plugin settings UI to add an enable/disable switch, dependency management for upstream icon themes, collapsible sections, GTK/QT icon theme integration, and a streamlined first-time setup experience.

## UI Layout

```
┌─────────────────────────────────────┐
│ [Toggle] Enable Noctalia Folders    │  <- top-level, gates all sections
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Appearance                          │
│   Accent source: [Primary v]       │
│   Icon theme:    [Papirus v]       │
│   Method:        [Recolor v]       │  <- both Papirus and Adwaita
│   [x] Dim mode                     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Dependency Status                   │
│                                     │
│ Papirus                             │
│   * papirus-icon-theme    Installed │
│   * papirus-folders    Not installed│ [Install]
│                                     │
│ Adwaita                             │
│   * Adwaita (base)        Installed │
│   * Adwaita Colors     Not installed│ [Install]
│   * MoreWaita          Not installed│ [Install]
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ > Behavior              (collapsed) │
│   [x] Auto-apply on theme change   │
│   [x] Set GTK icon theme           │
│   [x] Set QT icon theme            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ > Advanced              (collapsed) │
│   Rebuild Icon Cache    [Button]    │
│   [ ] Debug logging                │
└─────────────────────────────────────┘
```

## Enable Switch

- Default: **off**
- Stored as `enabled` in pluginSettings
- **Turning off:** calls `resetFolders()` to restore default icons, stops auto-apply, plugin becomes inert
- **Turning on:** checks dependencies, highlights missing ones in Dependency Status, applies if deps are satisfied
- All sections below the switch are disabled/dimmed when off
- IPC can enable/disable regardless of UI state (`enable` / `disable` commands)

## Appearance

- **Accent source:** Primary, Secondary, Tertiary, Hover (unchanged)
- **Icon theme:** Papirus or Adwaita
- **Method:** Recolor or Closest Match — applies to both themes
  - Recolor: sed-based SVG recoloring for exact accent color match
  - Closest Match: picks nearest preset from papirus-folders (Papirus) or Adwaita-colors (Adwaita)
- **Dim mode:** desaturate/darken the accent (unchanged)

### Icon theme mode values

Old: `papirus`, `adwaita-recolor`, `adwaita-match`
New: `papirus-recolor`, `papirus-match`, `adwaita-recolor`, `adwaita-match`

## Dependency Status

### Detection paths (user then system)

| Dependency | Check |
|---|---|
| papirus-icon-theme | `~/.local/share/icons/Papirus-Dark` or `/usr/share/icons/Papirus-Dark` |
| papirus-folders | `command -v papirus-folders` |
| Adwaita (base) | `~/.local/share/icons/Adwaita` or `/usr/share/icons/Adwaita` |
| Adwaita Colors | `~/.local/share/icons/Adwaita-blue` or `/usr/share/icons/Adwaita-blue` |
| MoreWaita | `~/.local/share/icons/MoreWaita` or `/usr/share/icons/MoreWaita` |

### Install methods (to ~/.local/share/icons/)

| Dependency | Install command |
|---|---|
| papirus-icon-theme | `wget -qO- https://git.io/papirus-icon-theme-install \| env DESTDIR="$HOME/.local/share/icons" sh` |
| papirus-folders | `git clone https://github.com/PapirusDevelopmentTeam/papirus-folders.git /tmp/papirus-folders && /tmp/papirus-folders/install.sh` |
| Adwaita Colors | `git clone https://github.com/dpejoh/Adwaita-colors.git /tmp/adwaita-colors && cd /tmp/adwaita-colors && ./setup -i` |
| MoreWaita | `git clone https://github.com/somepaulo/MoreWaita.git /tmp/morewaita && cd /tmp/morewaita && ./install.sh` |

### Visual indicators

- Green dot: installed
- Red dot: not installed, required for current mode
- Grey dot: not installed, not needed for current mode

Install buttons open a terminal process, re-run install check on exit.

### Dependency requirements by mode

| Mode | Required | Optional |
|---|---|---|
| papirus-recolor | papirus-icon-theme | - |
| papirus-match | papirus-folders | papirus-icon-theme (for Inherits) |
| adwaita-recolor | Adwaita (base) | MoreWaita (Inherits chain) |
| adwaita-match | Adwaita Colors | MoreWaita (Inherits chain) |

## Behavior (collapsible, collapsed by default)

All three options default to **on**.

- **Auto-apply on theme change:** automatically recolor when Noctalia accent changes
- **Set GTK icon theme:** on apply, set icon theme via gsettings + gtk-3.0/gtk-4.0 settings.ini
- **Set QT icon theme:** on apply, write icon_theme under [Appearance] in:
  - `~/.config/qt5ct/qt5ct.conf`
  - `~/.config/qt6ct/qt6ct.conf`
  - `~/.config/kdeglobals` under [Icons] Theme=
  - Only writes to config files that already exist (respects user's platform)

## Advanced (collapsible, collapsed by default)

- **Rebuild Icon Cache:** button, runs gtk-update-icon-cache (unchanged)
- **Debug logging:** toggle, enables verbose script output (unchanged)
- "Reset to Default Icons" button removed — disabling the plugin handles this

## Collapsible implementation

Each collapsible section is an NBox with a clickable header row containing a direction indicator. A `property bool expanded: false` toggles `visible` on the content ColumnLayout. Header shows triangular indicator when collapsed/expanded.

## Backend Changes

### manifest.json

New default settings:

```json
{
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

### Main.qml

- New `enabled` property; when false, skip auto-apply/startup apply
- `resetFolders()` called on disable
- New IPC: `enable()`, `disable()`
- Expanded install check for all 5 dependencies
- Support 4 icon theme modes: papirus-recolor, papirus-match, adwaita-recolor, adwaita-match

### Bash script

- `--set-gtk` / `--no-set-gtk` and `--set-qt` / `--no-set-qt` flags
- QT icon theme writing in `apply_icon_theme()` (qt5ct.conf, qt6ct.conf, kdeglobals)
- New `papirus-match` mode calling `papirus-folders -C <nearest_color>`
- Color-distance logic for nearest papirus-folders preset
- `--install-dep <name>` flag for dependency installation
- Existing adwaita-match mode updated to use Adwaita-colors variants

### Settings.qml

- Enable switch at top
- Dependency Status split into Papirus/Adwaita with 5 checks
- Behavior and Advanced as collapsible sections
- GTK/QT toggle bindings
- Method combo enabled for both icon themes
- "Reset to Default Icons" button removed

## Files to modify

- `noctalia-folders/manifest.json`
- `noctalia-folders/Settings.qml`
- `noctalia-folders/Main.qml`
- `noctalia-folders/scripts/noctalia-folders`
