#!/usr/bin/env python3
"""Pack generated originals at the terrain contract sizes and remove wrap discontinuities.
Usage: python prepare_assets.py source_paths.json
JSON maps each slot to its original local PNG. Requires Pillow and numpy.
This only resamples/packs assets; it never synthesizes painted details.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]


def periodic(image, horizontal_only=False):
    """Periodic-plus-smooth decomposition preserves high-frequency brush detail."""
    a = np.asarray(image.convert('RGB'), dtype=float)
    h, w, _ = a.shape
    boundary = np.zeros_like(a)
    if not horizontal_only:
        boundary[0] += a[-1] - a[0]
        boundary[-1] += a[0] - a[-1]
    boundary[:, 0] += a[:, -1] - a[:, 0]
    boundary[:, -1] += a[:, 0] - a[:, -1]
    denom = 2 * np.cos(2 * np.pi * np.arange(w) / w)[None, :] + 2 * np.cos(
        2 * np.pi * np.arange(h) / h
    )[:, None] - 4
    denom[0, 0] = 1
    smooth = np.fft.fft2(boundary, axes=(0, 1)) / denom[:, :, None]
    smooth[0, 0] = 0
    a -= np.fft.ifft2(smooth, axes=(0, 1)).real
    # Identical outer texels make hardware repeat filtering exact at the boundary.
    a[:, 0] = a[:, -1] = (a[:, 0] + a[:, -1]) / 2
    if not horizontal_only:
        a[0] = a[-1] = (a[0] + a[-1]) / 2
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def main():
    sources = json.loads(Path(sys.argv[1]).read_text())
    manifest = {}
    for slot, source in sources.items():
        image = Image.open(source)
        original_size = image.size
        if slot == 'decals':
            # Independently resample each source cell to prevent neighboring-cell bleed.
            packed = Image.new('RGBA', (768, 384))
            for row in range(4):
                for col in range(8):
                    cell = image.crop((round(col * image.width / 8), round(row * image.height / 4),
                                       round((col + 1) * image.width / 8), round((row + 1) * image.height / 4)))
                    cell.thumbnail((80, 80), Image.Resampling.LANCZOS)
                    packed.alpha_composite(cell, (col * 96 + (96 - cell.width) // 2,
                                                  row * 96 + (96 - cell.height) // 2))
            image = packed
        elif slot == 'bank':
            # Generated strip puts waterline at ~45% height; center that in contract.
            center = round(image.height * .45)
            half = round(image.width / 20)
            image = image.crop((0, center - half, image.width, center + half))
            image = periodic(image.resize((1920, 192), Image.Resampling.LANCZOS), True)
        else:
            image = periodic(image.resize((1920, 1920), Image.Resampling.LANCZOS))
        target = ROOT / 'art/rendered' / (slot + '.png')
        image.save(target)
        manifest[slot] = {'source': Path(source).name, 'source_size': original_size,
                          'source_sha256': hashlib.sha256(Path(source).read_bytes()).hexdigest(),
                          'packed_size': image.size}
    (Path(__file__).parent / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
