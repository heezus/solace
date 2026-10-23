import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw

here=Path('docs/art/livewire/bloom-tide'); specs=[]
for name in ['bloom_tide','bloom_tide_field','bloom_tide_wood']:
 p=Path('art/rendered')/(name+'.png'); im=Image.open(p).convert('RGBA'); a=im.getchannel('A')
 assert a.getextrema()==(0,255),name
 specs.append(dict(id=name,path='res://'+str(p),source_size=list(im.size),region=[0,0,im.width,im.height],footprint=[1,1],native_size=48,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),alpha_over_8_fraction=round(sum(a.histogram()[9:])/(im.width*im.height),3)))
(here/'spec.json').write_text(json.dumps(specs,indent=2)+'\n')
board=Image.new('RGB',(1000,420),'#263e35'); d=ImageDraw.Draw(board)
d.text((20,18),'Bloom tide / full-cell 48 px + 96 px / documentation composite, not runtime',fill='#eee4ca')
grass=Image.open('art/rendered/era-ground/livewire-healthy.png').convert('RGBA').crop((100,100,500,500))
for i,s in enumerate(specs):
 x=25+i*245; d.text((x,65),s['id'],fill='#eee4ca'); im=Image.open(s['path'].replace('res://',''))
 for dx,size in [(0,48),(80,96)]:
  tile=grass.resize((size,size),Image.Resampling.LANCZOS); icon=im.resize((size,size),Image.Resampling.LANCZOS); tile.alpha_composite(icon)
  board.paste(tile,(x+dx,110+96-size)); d.text((x+dx,220),str(size)+' px',fill='#eee4ca')
 # A bare-alpha view makes sparse coverage and creeping edges reviewable.
 icon=im.resize((96,96),Image.Resampling.LANCZOS); board.paste(icon,(x+50,275),icon)
 d.text((x,385),'alpha coverage '+str(s['alpha_over_8_fraction']),fill='#eee4ca')
x=760; d.text((x,65),'current painted Bloom material',fill='#eee4ca'); d.text((x,82),'#115 source sample / not runtime',fill='#eee4ca')
tile=Image.open('art/rendered/era-ground/livewire-bloom.png').convert('RGBA').crop((100,100,500,500)).resize((96,96),Image.Resampling.LANCZOS)
board.paste(tile,(x,110)); d.text((x,220),'96 px material comparison',fill='#eee4ca')
d.text((x,280),'New tide: young, open,',fill='#eee4ca'); d.text((x,300),'reaching botanical edges.',fill='#eee4ca')
board.save(here/'native-review.png')
