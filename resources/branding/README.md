# Branding resources

Consumed by the patches in `../../patches/branding/`, which point Chromium's
build at this directory in place of `chrome/app/theme/chromium`.

| File | Used for |
| --- | --- |
| `BRANDING` | Product strings: name, bundle id, copyright. Read by the build. |
| `product_logo_*.png` | Application icon, all the sizes Chromium asks for. |
| `evil-app-icon.svg` | Vector source for the above. |
| `evil-mark-*.svg` | The mark alone, for in-product surfaces. |
| `evil.desktop` | Linux desktop entry, installed to `/usr/share/applications`. |

Regenerate the PNGs after changing the SVG:

```sh
for s in 16 32 48 64 128 256 512; do
  rsvg-convert -w $s -h $s evil-app-icon.svg -o product_logo_$s.png
done
```

## Trademark

The BSD licence on the code does **not** extend to the evil name or to the mark
in this directory. Fork the code freely; if you distribute a build, replace this
directory with your own branding and ship it under your own name. That is a
normal condition for a Chromium derivative, and it exists so that a binary
calling itself "evil" is one whose privacy claims we can actually stand behind.
