#!/usr/bin/env python3
"""
Draws the GPS Checker app icon: a green radar sweep with a position fix on a dark navy field.

    python3 tools/make_app_icon.py

Writes GPSTest/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024, opaque).
Needs Pillow (`pip install pillow`).
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
SCALE = 4  # draw large, then downsample for smooth edges
NAVY = (14, 27, 48)
GREEN = (76, 217, 100)
DIM = (76, 217, 100, 90)


def main() -> None:
    s = SIZE * SCALE
    img = Image.new("RGBA", (s, s), NAVY + (255,))
    draw = ImageDraw.Draw(img, "RGBA")
    c = s / 2

    # Sweep wedge behind the rings.
    sweep = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(sweep).pieslice([c - s * 0.38, c - s * 0.38, c + s * 0.38, c + s * 0.38],
                                   start=-90, end=-30, fill=(76, 217, 100, 70))
    img.alpha_composite(sweep)

    for r, w in ((0.38, 0.016), (0.26, 0.012), (0.14, 0.012)):
        draw.ellipse([c - s * r, c - s * r, c + s * r, c + s * r], outline=GREEN, width=int(s * w))
    line = int(s * 0.008)
    draw.line([c, c - s * 0.42, c, c + s * 0.42], fill=DIM, width=line)
    draw.line([c - s * 0.42, c, c + s * 0.42, c], fill=DIM, width=line)

    # The fix: a bright dot with a halo, off-centre in the sweep.
    fx, fy, fr = c + s * 0.12, c - s * 0.19, s * 0.045
    draw.ellipse([fx - fr * 2, fy - fr * 2, fx + fr * 2, fy + fr * 2], fill=(76, 217, 100, 80))
    draw.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=(255, 255, 255, 255))

    out = ROOT / "GPSTest/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(out, optimize=True)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
