#!/usr/bin/env python3
"""
Renders the Moon's near side as seen from Earth from NASA's LRO colour map, for the Time screen.

    python3 tools/make_moon_image.py

Source: NASA Scientific Visualization Studio, CGI Moon Kit (https://svs.gsfc.nasa.gov/4720), a global
colour mosaic from the Lunar Reconnaissance Orbiter Camera. NASA imagery is in the public domain.

Writes GPSTest/Resources/Assets.xcassets/Moon.imageset/Moon.png: a 1024 x 1024 disc on a transparent
background, north up, orthographic projection centred on 0° latitude, 0° longitude.
Needs Pillow and NumPy (`pip install pillow numpy`).
"""

import io
import json
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCES = [
    "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_4k.tif",
    "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_2k.tif",
]
SIZE = 1024
SUPERSAMPLE = 2

Image.MAX_IMAGE_PIXELS = None


def download() -> Image.Image:
    for url in SOURCES:
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                print(f"Downloaded {url}")
                return Image.open(io.BytesIO(response.read())).convert("RGB")
        except Exception as error:  # try the next resolution
            print(f"Could not fetch {url}: {error}")
    raise SystemExit("No Moon texture could be downloaded.")


def render(texture: Image.Image) -> Image.Image:
    tex = np.asarray(texture, dtype=np.float32)
    height, width, _ = tex.shape
    n = SIZE * SUPERSAMPLE
    # Pixel centres in [-1, 1], y up.
    coords = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(coords, -coords)
    r2 = x * x + y * y
    inside = r2 <= 1
    z = np.sqrt(np.clip(1 - r2, 0, 1))
    lat = np.arcsin(np.clip(y, -1, 1))
    lon = np.arctan2(x, z)
    # Equirectangular map: longitude -180..180 left to right (0° in the middle), latitude 90..-90 top to bottom.
    u = ((lon / (2 * np.pi) + 0.5) * width).astype(np.int64) % width
    v = np.clip(((0.5 - lat / np.pi) * height).astype(np.int64), 0, height - 1)
    rgb = tex[v, u]
    alpha = inside.astype(np.float32) * 255
    image = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(image, "RGBA").resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    folder = ROOT / "GPSTest/Resources/Assets.xcassets/Moon.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    render(download()).save(folder / "Moon.png", optimize=True)
    contents = {
        "images": [{"filename": "Moon.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {folder / 'Moon.png'}")


if __name__ == "__main__":
    main()
