#!/usr/bin/env python3
"""Mechanical packing of imagegen paintings; no painted detail is synthesized.
Run: uv run --with pillow --with numpy python docs/art/terrain-kit/era-ground/pack_assets.py
Originals remain untouched. Matches the parent kit's periodic-plus-smooth preparation.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUTPUT = ROOT / "art/rendered/era-ground"
SHEETS = {
    "corrections-v2/starfall-meadow-quiet-source.png": "starfall-meadow.png",
    "corrections-v2/starfall-woodland-quiet-source.png": "starfall-woodland.png",
    "corrections-v2/earth-south-source.png": "earth-south.png",
    "corrections-v2/livewire-firebreak-source.png": "livewire-firebreak.png",
    "corrections-v2/livewire-healthy-source.png": "livewire-healthy.png",
    "corrections-v2/bronze-dawn-earth-source.png": "bronze-dawn-earth.png",
    "corrections-v2/ironfall-apron-source.png": "ironfall-apron.png",
    "corrections-v2/livewire-bloom-source.png": "livewire-bloom.png",
}


def periodic(image):
    """Remove only wrap discontinuity, without reflection or cloned landmarks."""
    a = np.asarray(image.convert("RGB"), dtype=float)
    h, w, _ = a.shape
    boundary = np.zeros_like(a)
    boundary[0] += a[-1] - a[0]
    boundary[-1] += a[0] - a[-1]
    boundary[:, 0] += a[:, -1] - a[:, 0]
    boundary[:, -1] += a[:, 0] - a[:, -1]
    denom = (2 * np.cos(2 * np.pi * np.arange(w) / w)[None, :]
             + 2 * np.cos(2 * np.pi * np.arange(h) / h)[:, None] - 4)
    denom[0, 0] = 1
    smooth = np.fft.fft2(boundary, axes=(0, 1)) / denom[:, :, None]
    smooth[0, 0] = 0
    a -= np.fft.ifft2(smooth, axes=(0, 1)).real
    a[:, 0] = a[:, -1] = (a[:, 0] + a[:, -1]) / 2
    a[0] = a[-1] = (a[0] + a[-1]) / 2
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = {}
    for source, target in SHEETS.items():
        path = HERE / source
        original = Image.open(path)
        packed = periodic(original.resize((1920, 1920), Image.Resampling.LANCZOS))
        out = OUTPUT / target
        packed.save(out)
        a = np.asarray(packed)
        assert np.array_equal(a[:, 0], a[:, -1])
        assert np.array_equal(a[0], a[-1])
        # Review proof is a literal 2x2 repeat, not a mirrored presentation.
        board = Image.new("RGB", (1920, 1920))
        half = packed.resize((960, 960), Image.Resampling.LANCZOS)
        for x, y in [(0, 0), (960, 0), (0, 960), (960, 960)]:
            board.paste(half, (x, y))
        board.save(HERE / (target.removesuffix(".png") + "-wrap-review.jpg"), quality=93)
        records[target] = {"source": source, "source_size": list(original.size),
                           "source_sha256": sha(path), "packed_size": list(packed.size),
                           "packed_sha256": sha(out), "wrap_edge_max_difference": 0,
                           "mean_rgb": np.mean(a, axis=(0, 1)).round(2).tolist()}
    # Atlas objects stay within their existing cells; alpha is not keyed or invented.
    source = HERE / "decals-objects-source.png"
    if source.exists():
        original = Image.open(source).convert("RGBA")
        packed = Image.new("RGBA", (768, 384))
        for row in range(4):
            for col in range(8):
                cell = original.crop((round(col * original.width / 8),
                                      round(row * original.height / 4),
                                      round((col + 1) * original.width / 8),
                                      round((row + 1) * original.height / 4)))
                # Trim the empty outer gutter (including generation grid artefacts).
                margin_x, margin_y = round(cell.width * .10), round(cell.height * .10)
                cell = cell.crop((margin_x, margin_y, cell.width - margin_x, cell.height - margin_y))
                cell.thumbnail((44, 44), Image.Resampling.LANCZOS)
                packed.alpha_composite(cell, (col * 96 + (96 - cell.width) // 2,
                                             row * 96 + (96 - cell.height) // 2))
        out = OUTPUT / "decals.png"
        packed.save(out)
        alpha = np.asarray(packed)[:, :, 3]
        for row in range(4):
            for col in range(8):
                cell_alpha = alpha[row * 96:(row + 1) * 96, col * 96:(col + 1) * 96]
                assert not cell_alpha[:8].any() and not cell_alpha[-8:].any()
                assert not cell_alpha[:, :8].any() and not cell_alpha[:, -8:].any()
        records[out.name] = {"source": source.name, "source_size": list(original.size),
                             "source_sha256": sha(source), "packed_size": list(packed.size),
                             "packed_sha256": sha(out), "alpha_preserved": True}
    (HERE / "sources.json").write_text(json.dumps(records, indent=2) + "\n")
    print("Packed", len(records), "assets; exact wrap edges verified on", len(SHEETS), "sheets")


if __name__ == "__main__":
    main()
