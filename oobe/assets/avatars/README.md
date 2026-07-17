# Preset avatars

Drop any square-ish `.png` / `.jpg` / `.jpeg` images in this folder and they'll
automatically show up as pickable preset avatars on the OOBE avatar page —
no code changes needed, just re-run `cmake` (the install script always
configures fresh, so a normal `sudo ./install-ativos-oobe.sh` picks them up
too).

Notes:
- Images are baked into the `ativos-oobe` binary at build time (Qt resource
  system), so they always work offline with no extra files to ship on the
  ISO — just this repo.
- Square images look best; the picker crops to a circle.
- Keep individual files reasonably small (a few hundred KB, ideally
  downscaled to ~512x512) since every preset adds to the binary size.
- Filenames don't matter — they're only used internally, never shown to
  the user.

This file is just a placeholder so the empty folder survives a git commit;
delete it once real avatars are added, or leave it, doesn't matter.
