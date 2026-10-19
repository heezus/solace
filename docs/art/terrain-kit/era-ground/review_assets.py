#!/usr/bin/env python3
"""Asset contact sheet at native game scales; explicitly NOT an engine screenshot."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ART = ROOT / 'art/rendered/era-ground'
NAMES = [('Starfall meadow', 'starfall-meadow'), ('Starfall woodland', 'starfall-woodland'),
         ('Bronze Dawn', 'bronze-dawn-earth'), ('Ironfall south', 'earth-south'),
         ('Coal / Ironstone apron', 'ironfall-apron'), ('Livewire healthy', 'livewire-healthy'),
         ('Livewire Bloom', 'livewire-bloom'), ('Livewire firebreak', 'livewire-firebreak')]
board = Image.new('RGB', (1560, 1610), '#202b27')
draw = ImageDraw.Draw(board)
font = ImageFont.load_default(size=20)
small = ImageFont.load_default(size=15)
draw.text((20, 12), 'ERA GROUND ASSET PROOF - composite, not a game screenshot', font=font, fill='#eee8d3')
draw.text((20, 42), 'Close: 80 px/tile, existing Hearth at 2x2 footprint. Wide strip: 24 px/tile. No shader blends applied.', font=small, fill='#bcc7b3')
hearth = Image.open(ROOT / 'art/rendered/buildings.png').convert('RGBA').crop((35, 690, 458, 1051))
hearth.thumbnail((160, 160), Image.Resampling.LANCZOS)
for i, (name, filename) in enumerate(NAMES):
    x, y = (i % 3) * 520 + 20, (i // 3) * 510 + 80
    draw.text((x, y), name, font=font, fill='#eee8d3')
    sheet = Image.open(ART / (filename + '.png')).convert('RGBA')
    close = sheet.crop((576, 576, 960, 960)).resize((320, 320), Image.Resampling.LANCZOS)
    close.alpha_composite(hearth, ((320 - hearth.width) // 2, (320 - hearth.height) // 2))
    board.paste(close.convert('RGB'), (x, y + 32))
    wide = sheet.resize((480, 480), Image.Resampling.LANCZOS).crop((0, 100, 480, 220))
    board.paste(wide.convert('RGB'), (x, y + 370))
board.save(HERE / 'asset-scale-review.jpg', quality=95)
print('Wrote asset-scale-review.jpg')
