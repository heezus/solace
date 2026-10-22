import hashlib, json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

group=Path(sys.argv[1]); ids=sys.argv[2:]
specs=[]
for name in ids:
 p=Path('art/rendered')/(name+'.png'); im=Image.open(p).convert('RGBA')
 assert im.getchannel('A').getextrema()==(0,255), name
 b=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
 # Two source pixels of padding retain antialiasing around visible subject.
 b=(max(0,b[0]-2),max(0,b[1]-2),min(im.width,b[2]+2),min(im.height,b[3]+2))
 if name in ['firebreak','firebreak_end']: b=(0,0,im.width,im.height)
 if name=='firebreak_corner': b=(202,192,1058,1048)
 specs.append(dict(id=name,path='res://'+str(p),source_size=list(im.size),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),region=[b[0],b[1],b[2]-b[0],b[3]-b[1]],footprint=[1,1],native_size=46))
group.mkdir(parents=True,exist_ok=True)
(group/'spec.json').write_text(json.dumps(specs,indent=2)+'\n')
refs=['coal_mine','bloomery']
entries=specs+json.loads(Path('docs/art/ironfall/buildings/spec.json').read_text())
board=Image.new('RGB',(1000,300+((len(entries)+3)//4)*170),'#263e35'); d=ImageDraw.Draw(board)
d.text((20,16),'Solace / native 46 px inside 48 px tile + 96 px inspection',fill='#eee4ca')
d.text((20,40),'Unmodified transparent originals; alpha >8 bounds + 2 px padding. Existing references last.',fill='#eee4ca')
for i,s in enumerate(entries):
 x=20+(i%4)*245; y=90+(i//4)*170
 d.text((x,y),s['id'],fill='#eee4ca')
 im=Image.open(s['path'].replace('res://','')); r=s['region']; im=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
 for dx,size in [(0,46),(75,96)]:
  thumb=im.copy(); thumb.thumbnail((size,size),Image.Resampling.LANCZOS)
  board.paste(thumb,(x+dx+(size-thumb.width)//2,y+25+96-thumb.height),thumb)
 d.text((x,y+130),'46 px              96 px',fill='#eee4ca')
if 'firebreak_end' in ids:
 y=board.height-190
 d.text((20,y),'Firebreak connected fixture / 48 px cells / end - straight - corner - straight - end',fill='#eee4ca')
 tiles={}
 for s in specs:
  if s['id'].startswith('firebreak'):
   im=Image.open(s['path'].replace('res://','')); r=s['region']
   tiles[s['id']]=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])).resize((48,48),Image.Resampling.LANCZOS)
 for name,turn,x,z in [('firebreak_end',180,0,0),('firebreak',0,1,0),('firebreak_corner',0,2,0),('firebreak',90,2,1),('firebreak_end',270,2,2)]:
  im=tiles[name].rotate(turn); board.paste(im,(30+x*48,y+20+z*48),im)
board.save(group/'native-review.png')
print('Wrote',group,'for',len(specs),'assets')
