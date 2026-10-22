#!/usr/bin/env python3
"""Losslessly package native terrain_preview outputs; never resize the screenshots.
Run: uv run --with pillow python <this script> /tmp/solace-era-integrated
"""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
root = Path(sys.argv[1])
records = []
for era in ['starfall', 'bronze', 'ironfall', 'livewire']:
    for seed in [3, 11, 42]:
        for mode, label in [('baseline', 'before'), ('current', 'after')]:
            folder = root / era / str(seed) / mode
            log = (folder / 'run.log').read_text()
            assert not any(x in log for x in ['ERROR', 'WARNING', 'Parse Error'])
            assert len(list(folder.glob('terrain_*.png'))) == 7
            for view in (['wide', 'close', 'town'] if seed == 3 else ['wide', 'close']):
                source = folder / f'terrain_{seed}_{view}.png'
                target = HERE / f'{era}-{seed}-{label}-{view}.webp'
                image = Image.open(source)
                assert image.size == (1280, 800)
                image.save(target, lossless=True, method=6)
                assert Image.open(target).convert(image.mode).tobytes() == image.tobytes()
                records.append({'era': era, 'preview_seed': seed, 'mode': mode, 'view': view,
                                'image': target.name, 'size': list(image.size),
                                'source_png_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                                'lossless_pixel_sha256': hashlib.sha256(image.tobytes()).hexdigest()})
(HERE / 'captures.json').write_text(json.dumps(records, indent=2) + '\n')
print(f'Packaged {len(records)} native before/after screenshots without resampling')
