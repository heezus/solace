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
 if name in ['shard_lamp','shard_lamp_lit']: b=(461,35,794,1213)
 if name=='rail': b=(444,0,1330,886)
 if name=='rail_corner': b=(200,80,1100,980)
 if name=='rail_t': b=(385,348,870,833)
 if name=='rail_cross': b=(301,301,951,951)
 if name=='rail_end': b=(0,182,886,1068)
 specs.append(dict(id=name,path='res://'+str(p),source_size=list(im.size),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),region=[b[0],b[1],b[2]-b[0],b[3]-b[1]],footprint=[1,1],native_size=46))
group.mkdir(parents=True,exist_ok=True)
(group/'spec.json').write_text(json.dumps(specs,indent=2)+'\n')
refs=['coal_mine','bloomery']
entries=specs+json.loads(Path('docs/art/ironfall/buildings/spec.json').read_text())
board=Image.new('RGB',(1000,100+((len(entries)+3)//4)*170),'#263e35'); d=ImageDraw.Draw(board)
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
board.save(group/'native-review.png')
if 'rail_cross' in ids:
 fixture=Image.new('RGB',(700,360),'#263e35'); fd=ImageDraw.Draw(fixture)
 fd.text((20,15),'Rail / connected 48 px sampling regions / original PNGs unchanged',fill='#eee4ca')
 tiles={}
 for s in specs:
  if s['id'].startswith('rail'):
   im=Image.open(s['path'].replace('res://','')); r=s['region']
   tiles[s['id']]=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])).resize((48,48),Image.Resampling.LANCZOS)
 for name,turn,x,y in [('rail',0,0,0),('rail',0,1,0),('rail_corner',0,2,0),('rail',90,2,1),('rail',90,2,2),('rail_t',0,5,0),('rail',0,4,0),('rail',0,6,0),('rail',90,5,1),('rail_cross',0,10,1),('rail',0,9,1),('rail',0,11,1),('rail',90,10,0),('rail',90,10,2)]:
  im=tiles[name].rotate(turn); fixture.paste(im,(30+x*48,60+y*48),im)
 if 'rail_end' in ids:
  im=tiles['rail_end'].rotate(270); fixture.paste(im,(30+2*48,60+3*48),im)
 fixture.save(group/'native-rail-review.png')
print('Wrote',group,'for',len(specs),'assets')
if 'beast_cart' in ids:
 cartboard=Image.new('RGB',(900,270),'#263e35'); cd=ImageDraw.Draw(cartboard)
 cd.text((20,15),'Cart variants / 36 px current caller (35 x 1.04, rounded) + 96 px inspection',fill='#eee4ca')
 carts=[dict(id='existing hand_cart',path='res://art/rendered/growth-hand-cart.png',region=[195,194,1150,775])]+[s for s in specs if s['id'] in ['steam_cart','beast_cart']]
 for i,s in enumerate(carts):
  x=30+i*290; cd.text((x,55),s['id'],fill='#eee4ca')
  im=Image.open(s['path'].replace('res://','')); r=s['region']; im=im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
  for dx,size in [(0,36),(90,96)]:
   thumb=im.copy(); thumb.thumbnail((size,size),Image.Resampling.LANCZOS); cartboard.paste(thumb,(x+dx,90+96-thumb.height),thumb)
  cd.text((x,210),'36 px          96 px',fill='#eee4ca')
 cartboard.save(group/'native-cart-review.png')
