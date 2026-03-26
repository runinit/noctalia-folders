# Noctalia Folders

## Project Structure
- `noctalia-folders/` — plugin directory (QML + bash)
  - `Main.qml` — runtime logic, process management, dep properties
  - `Settings.qml` — settings UI with tabbed layout
  - `scripts/noctalia-folders` — bash script for icon recoloring
  - `manifest.json` — plugin metadata and version
- `registry.json` — plugin registry (must match manifest version)
- `docs/plans/` — design docs and implementation plans (untracked)

## Release Process
- ALWAYS bump version in BOTH `noctalia-folders/manifest.json` AND `registry.json`
- Update `lastUpdated` in registry.json when bumping
- Push to master triggers update — user must restart Noctalia shell to pick up changes

## Code Patterns
- Dep check output: `user`/`system`/`0` for directory deps, `1`/`0` for CLI tools (papirus-folders)
- Settings UI uses a tabbed layout (replaced collapsible sections in 42457ca)
- Script's `mirror_parent_dirs()` only writes index.theme declarations (no dirs on disk) for flatpak compat
- `index.theme` must list parent theme dirs for Qt 6.10 icon inheritance
- QML dep properties are strings ("user"/"system"/"1"/"0"), not bools
- Script uses `apply_icon_theme()` with gsettings toggle (flash away/back) to force GTK refresh

## Testing
- `bash noctalia-folders/scripts/noctalia-folders --check-deps` — verify dep detection output
- `bash noctalia-folders/scripts/noctalia-folders --apply --icon-theme papirus-recolor --verbose --color-source mSecondary` — test apply
- Use `cat -A` to check for hidden chars in script output
- `rm -rf ~/.local/share/icons/Papirus-Noctalia` before `--apply` to test full install path (recolor alone skips install)
- `flatpak run org.gnome.seahorse.Application` — verify icon theme works inside flatpak sandbox
