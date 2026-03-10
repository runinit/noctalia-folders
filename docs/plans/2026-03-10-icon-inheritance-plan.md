# Icon Inheritance Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix Qt 6.10 icon fallback by mirroring parent theme's full directory structure in Noctalia theme index.theme files.

**Architecture:** Add a helper function that parses a parent theme's index.theme to extract all directory sections, then use it in both `do_install_papirus()` and `do_install_adwaita()` to declare the full directory set and create empty dirs for non-places contexts.

**Tech Stack:** Bash (existing script)

---

### Task 1: Add `mirror_parent_dirs()` helper function

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders:261` (insert before `do_install_papirus`)

**Step 1: Write the helper function**

Insert this function before `do_install_papirus()` (around line 261):

```bash
# ──────────────────────────────────────────────
# Mirror parent theme directories
# ──────────────────────────────────────────────
# Reads a parent theme's index.theme and:
#   1. Appends all non-places directory names to the Directories= line
#   2. Writes [section] entries for each non-places directory
#   3. Creates empty directories on disk
#
# Usage: mirror_parent_dirs <parent_index_theme> <noctalia_theme_dir> <noctalia_index_theme>
mirror_parent_dirs() {
    local parent_index="$1"
    local theme_dir="$2"
    local noctalia_index="$3"

    [ -f "$parent_index" ] || { msg "Warning: parent index.theme not found at $parent_index, skipping mirror"; return 0; }

    msg "  Mirroring directory declarations from $(dirname "$parent_index") ..."

    local extra_dirs=""
    local sections=""
    local current_section=""
    local in_section=false

    while IFS= read -r line; do
        # Match section headers like [48x48/apps]
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            # Skip [Icon Theme] header and any places directories (we handle those)
            if [[ "$current_section" == "Icon Theme" ]] || [[ "$current_section" == */places ]]; then
                in_section=false
                continue
            fi
            in_section=true
            sections+="[${current_section}]"$'\n'
            [ -n "$extra_dirs" ] && extra_dirs+=","
            extra_dirs+="$current_section"
        elif $in_section; then
            # Accumulate section content (Context=, Size=, Type=, etc.)
            if [[ -n "$line" ]]; then
                sections+="$line"$'\n'
            else
                sections+=$'\n'
                in_section=false
            fi
        fi
    done < "$parent_index"

    if [ -z "$extra_dirs" ]; then
        msg "  No extra directories found in parent theme"
        return 0
    fi

    # Append extra dirs to the Directories= line in noctalia index.theme
    sed -i "s|^Directories=\(.*\)|Directories=\1,${extra_dirs}|" "$noctalia_index"

    # Append section definitions
    printf '%s' "$sections" >> "$noctalia_index"

    # Create empty directories on disk
    local dir
    local IFS=','
    for dir in $extra_dirs; do
        mkdir -p "$theme_dir/$dir"
    done

    local count
    count="$(echo "$extra_dirs" | tr ',' '\n' | wc -l)"
    msg "  Mirrored $count directory declarations from parent theme"
}
```

**Step 2: Verify syntax**

Run: `bash -n noctalia-folders/scripts/noctalia-folders`
Expected: No output (clean parse)

**Step 3: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: add mirror_parent_dirs() helper for icon inheritance fix"
```

---

### Task 2: Update `do_install_papirus()` to mirror Papirus-Dark dirs

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders` — `do_install_papirus()` function

**Step 1: Add mirror call after index.theme generation**

After the existing loop that writes `[size/places]` sections (after line 301), add:

```bash
    # Mirror all non-places directories from parent theme for Qt compatibility
    local parent_index="$source_dir/index.theme"
    mirror_parent_dirs "$parent_index" "$theme_dir" "$theme_dir/index.theme"
```

**Step 2: Verify syntax**

Run: `bash -n noctalia-folders/scripts/noctalia-folders`
Expected: No output (clean parse)

**Step 3: Test install**

Run: `bash noctalia-folders/scripts/noctalia-folders --install --icon-theme papirus-recolor --verbose`

Verify:
- Output shows "Mirroring directory declarations from ..."
- Output shows "Mirrored N directory declarations from parent theme"

Then check the generated index.theme:

Run: `head -5 ~/.local/share/icons/Papirus-Noctalia/index.theme && echo "---" && grep -c '^\[' ~/.local/share/icons/Papirus-Noctalia/index.theme`

Expected: Directories= line contains many entries (not just places), section count ~211 (matching Papirus-Dark)

Run: `ls ~/.local/share/icons/Papirus-Noctalia/48x48/`

Expected: Both `places/` (with SVGs) and `apps/` (empty) directories exist

**Step 4: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: mirror Papirus-Dark dirs in Papirus-Noctalia for Qt 6.10 compat"
```

---

### Task 3: Update `do_install_adwaita()` to mirror Adwaita dirs

**Files:**
- Modify: `noctalia-folders/scripts/noctalia-folders` — `do_install_adwaita()` function

**Step 1: Add mirror call after index.theme generation**

After the existing loop that writes raster `[size/places]` sections (after line 384), add:

```bash
    # Mirror all non-places directories from parent theme for Qt compatibility
    local parent_index="$source_dir/index.theme"
    mirror_parent_dirs "$parent_index" "$theme_dir" "$theme_dir/index.theme"
```

**Step 2: Verify syntax**

Run: `bash -n noctalia-folders/scripts/noctalia-folders`
Expected: No output (clean parse)

**Step 3: Commit**

```bash
git add noctalia-folders/scripts/noctalia-folders
git commit -m "feat: mirror Adwaita dirs in Adwaita-Noctalia for Qt 6.10 compat"
```

---

### Task 4: End-to-end test — verify Qt icon resolution

**Step 1: Reinstall and apply**

Run: `bash noctalia-folders/scripts/noctalia-folders --install --icon-theme papirus-recolor --verbose`
Run: `bash noctalia-folders/scripts/noctalia-folders --apply --icon-theme papirus-recolor --verbose --color-source mSecondary`

**Step 2: Update icon cache**

Run: `gtk-update-icon-cache -qf ~/.local/share/icons/Papirus-Noctalia`

**Step 3: Verify visually**

- Open a Qt app (e.g., qt6ct, any KDE app) and check icons are Papirus, not Adwaita
- Check taskbar — app icons should be from Papirus-Dark, not Adwaita
- Folder icons should still show recolored accent
- No checkerboard/missing icons

**Step 4: If icons still wrong — fallback to symlinks**

If empty dirs don't trigger proper fallback, replace `mkdir -p` in `mirror_parent_dirs()` with symlinks:

```bash
# Replace: mkdir -p "$theme_dir/$dir"
# With:    ln -sfn "$source_dir/$dir" "$theme_dir/$dir"
```

This is the fallback plan if Qt doesn't honor declared-but-empty directories.
