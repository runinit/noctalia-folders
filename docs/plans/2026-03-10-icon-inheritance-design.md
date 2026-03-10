# Icon Inheritance Fix Design

## Problem

Qt 6.10 regression: Papirus-Noctalia only declares `places` directories in its
`index.theme`. Qt's icon loader no longer properly walks the `Inherits=` chain
for undeclared contexts (apps, actions, mimetypes, etc.), causing Qt apps to
skip Papirus-Dark and fall through to Adwaita or show missing-icon checkerboard.

GTK is unaffected — it still resolves inheritance correctly.

## Solution

Mirror the parent theme's full directory structure in the Noctalia theme's
`index.theme`, creating empty directories on disk for non-places contexts.

When Qt looks up e.g. `48x48/apps/firefox.svg` in Papirus-Noctalia:
1. Finds `48x48/apps` declared in index.theme
2. Checks the (empty) directory — no match
3. Falls through to `Inherits=Papirus-Dark` — finds the icon

### Changes to `do_install_papirus()`

1. Parse `/usr/share/icons/Papirus-Dark/index.theme` to extract all directory
   sections (name, Context, Size, Type, MinSize, MaxSize, Threshold)
2. Write all directory entries to Papirus-Noctalia's `index.theme`
3. Create empty directories on disk for non-places contexts
4. Places directories still populated with recolored SVGs (unchanged)

### Changes to `do_install_adwaita()`

Same approach: parse Adwaita's `index.theme`, mirror all directory declarations,
create empty dirs for non-places contexts.

### Why not symlinks?

Empty dirs + declarations is cleaner:
- No symlink management complexity
- No risk of broken symlinks if parent theme updates
- Minimal disk footprint (empty dirs)
- Falls back naturally via `Inherits=` chain

### Risk

If Qt 6.10 treats "declared directory exists but icon not found" differently
from "directory not declared at all", this won't work. Fallback plan: symlink
non-places directories to the parent theme.
