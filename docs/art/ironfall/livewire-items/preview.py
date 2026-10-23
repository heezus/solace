import hashlib, json
from pathlib import Path
from PIL import Image, ImageDraw

here=Path('docs/art/ironfall/livewire-items')
specs=[]
for name in ['wire','steel_tools','shard']:
 p=Path('art/rendered')/(name+'.png'); im=Image.open(p).convert('RGBA'); a=im.getchannel('A')
 assert a.getextrema()==(0,255),name
 b=a.point(lambda v:255 if v>8 else 0).getbbox(); b=(max(0,b[0]-2),max(0,b[1]-2),min(im.width,b[2]+2),min(im.height,b[3]+2))
 specs.append(dict(id=name,path='res://'+str(p),source_size=list(im.size),region=[b[0],b[1],b[2]-b[0],b[3]-b[1]],sha256=hashlib.sha256(p.read_bytes()).hexdigest(),native_size=20))
(here/'spec.json').write_text(json.dumps(specs,indent=2)+'\n')
entries=specs+[s for s in json.loads(Path('docs/art/ironfall/items/spec.json').read_text()) if s['id']=='iron_tools']
board=Image.new('RGB',(1000,620),'#263e35'); d=ImageDraw.Draw(board)
d.text((20,18),'Solace item icons / 20, 24, 32, 40 and 96 px / originals + measured regions',fill='#eee4ca')
for row,bg,fg in [(0,'#263e35','#eee4ca'),(1,'#eee4ca','#263e35')]:
 d.rectangle((0,50+row*280,1000,330+row*280),fill=bg)
 for i,s in enumerate(entries):
  x=20+i*245; y=70+row*280; d.text((x,y),s['id']+(' (existing)' if i==3 else ''),fill=fg)
  im=Image.open(s['path'].replace('res://','')); r=s['region']; im=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
  for dx,size in [(0,20),(40,24),(85,32),(135,40),(35,96)]:
   t=im.copy(); t.thumbnail((size,size),Image.Resampling.LANCZOS)
   by=y+70 if size<96 else y+195
   board.paste(t,(x+dx+(size-t.width)//2,by-t.height),t)
   d.text((x+dx,by+8),str(size),fill=fg)
board.save(here/'native-review.png')
