---
name: test-theme
description: Clean reinstall Papirus-Noctalia theme and verify in host + flatpak
disable-model-invocation: true
---

# Test Theme

Full clean reinstall and verification of the Papirus-Noctalia icon theme.

## Steps

1. **Remove existing theme** to force full install path:
   ```bash
   rm -rf ~/.local/share/icons/Papirus-Noctalia
   ```

2. **Re-apply the theme**:
   ```bash
   bash noctalia-folders/scripts/noctalia-folders --apply --icon-theme papirus-recolor --verbose --color-source mSecondary
   ```

3. **Verify no stale symlinks** outside places dirs:
   ```bash
   find ~/.local/share/icons/Papirus-Noctalia/ -maxdepth 2 -type l -not -path '*/places/*'
   ```
   Expected: no output (zero symlinks).

4. **Verify index.theme declarations** still list non-places dirs:
   ```bash
   head -10 ~/.local/share/icons/Papirus-Noctalia/index.theme
   ```
   The `Directories=` line should include entries like `16x16/actions`, `48x48/apps`, etc.

5. **Test flatpak app** (GTK, most likely to break on icon issues):
   ```bash
   flatpak run org.gnome.seahorse.Application &
   FPID=$!
   sleep 3
   kill $FPID 2>/dev/null
   wait $FPID 2>/dev/null
   ```
   Expected: exit code 143 (SIGTERM from our kill), NOT a crash/assertion failure.

6. **Report results** — summarize pass/fail for each check.
