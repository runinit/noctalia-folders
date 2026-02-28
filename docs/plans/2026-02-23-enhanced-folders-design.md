# Enhanced noctalia-folders Plugin Design

## Summary

Extend the noctalia-folders plugin to support three icon theme modes (Papirus recolor, Adwaita closest-match, Adwaita recolor), add a dim mode that desaturates+darkens the accent, show accent color preview in settings, and make the icon theme configurable.

## Icon Theme Modes

### 1. Papirus Recolored (`papirus`)
Current behavior. Copies Papirus-Dark places SVGs into Papirus-Noctalia, sed-replaces 3 base blue colors (#5294e2, #4877b1, #1d344f) with accent-derived shades.

### 2. Adwaita Closest Match (`adwaita-match`)
Maps mPrimary to the nearest built-in Adwaita-{color} theme by color distance. No SVG modification — just switches the icon theme via gsettings/GTK/KDE config. Available Adwaita accent themes and their primary colors:

| Theme | Primary Color |
|-------|--------------|
| Adwaita (base/blue) | #3584e4 |
| Adwaita-blue | #3584e4 |
| Adwaita-brown | #986a44 |
| Adwaita-green | #3a944a |
| Adwaita-orange | #ed5b00 |
| Adwaita-pink | #d56199 |
| Adwaita-purple | #954ab5 |
| Adwaita-red | #e62d42 |
| Adwaita-slate | #6f8396 |
| Adwaita-teal | #2190a4 |
| Adwaita-yellow | #c88800 |

Color distance calculated using simple Euclidean distance in RGB space.

### 3. Adwaita Recolored (`adwaita-recolor`)
Copies Adwaita scalable/places SVGs into Adwaita-Noctalia, sed-replaces 5 base blue colors (#438de6, #62a0ea, #a4caee, #afd4ff, #c0d5ea) with accent-derived shades. Derives 5 shades by applying the same relative HSL offsets from the base blue set to the target accent.

## Dim Mode

A boolean toggle. When enabled, before deriving folder shades, the accent color is first:
- Desaturated by ~30% (reduce HSL saturation)
- Darkened by ~15% (reduce HSL lightness)

This feeds into the existing derivation pipeline, producing muted folder colors.

## Settings.qml Changes

- **Icon theme mode**: NComboBox with options: "Papirus (Recolored)", "Adwaita (Closest Match)", "Adwaita (Recolored)"
- **Accent color preview**: Rectangle showing Color.mPrimary with the hex label
- **Dim mode toggle**: NToggle for desaturate+darken
- **Auto-apply toggle**: Existing
- **Script path override**: Existing
- **Manual action buttons**: Existing (Apply, Reset, Reinstall)

## Default Settings

```json
{
    "autoApply": true,
    "scriptPath": "",
    "iconTheme": "papirus",
    "dimMode": false
}
```

## Bash Script Changes

New flags:
- `--icon-theme papirus|adwaita-match|adwaita-recolor` (default: papirus)
- `--dim` flag to enable dim mode

Install creates the appropriate theme (Papirus-Noctalia or Adwaita-Noctalia) based on mode. For adwaita-match mode, install is a no-op (just switches theme). Reset reverts to the appropriate base theme (Papirus-Dark or Adwaita).

## IPC Changes

The `apply` command reads iconTheme and dimMode from plugin settings and passes them to the script. All 4 IPC commands remain: apply, reset, status, install.
