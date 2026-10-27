import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
p=Path('docs/art/tellings/map-relics')
ids=['ruins','ruins_2','ruins_cleared','bloom_dormant','relic_dig','first_wreck','first_wreck_2','relic_everburning_forge','relic_old_lantern','relic_founders_cart']
spec=[]
for stem in ids:
 f=Path('art/rendered')/(stem+'.png'); im=Image.open(f).convert('RGBA');assert im.getchannel('A').getextrema()==(0,255)
 b=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox(); b=(max(0,b[0]-2),max(0,b[1]-2),min(im.width,b[2]+2),min(im.height,b[3]+2))
 s=dict(id=stem,path='res://'+str(f),size=list(im.size),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),region=[b[0],b[1],b[2]-b[0],b[3]-b[1]],original_pixels=True)
 s.update(dict(icon_size=20) if stem.startswith('relic_') and stem!='relic_dig' else dict(footprint=[1,1],fit_box=46))
 spec.append(s)
(p/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
board=Image.new('RGB',(1200,1120),'#243a31');d=ImageDraw.Draw(board)
d.text((20,16),'Solace / new map subjects: 46 px inside 48 px cells + 96 px inspection',fill='#eee4ca')
d.text((20,38),'Original transparent sources; alpha >8 bounds + 2 px padding. References normalized for material comparison.',fill='#eee4ca')
entries=[(s['id'],s['path'].replace('res://',''),s['region']) for s in spec[:7]]
for name in ['bloomery','bloom_tide','starfall-wreck']:
 im=Image.open('art/rendered/'+name+'.png').convert('RGBA');b=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox(); entries.append((name+' (existing)','art/rendered/'+name+'.png',[b[0],b[1],b[2]-b[0],b[3]-b[1]]))
for i,(name,f,r) in enumerate(entries):
 x=20+(i%4)*295;y=85+(i//4)*220;d.text((x,y),name,fill='#eee4ca');im=Image.open(f).convert('RGBA').crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
 for dx,size in [(0,46),(85,96)]:
  t=im.copy();t.thumbnail((size,size),Image.Resampling.LANCZOS);board.paste(t,(x+dx+(size-t.width)//2,y+30+100-t.height),t)
 d.text((x,y+145),'46 px           96 px',fill='#eee4ca')
 # same-height existing Kith beside the new one-cell subjects
 if i<7:
  k=Image.open('art/rendered/walk.png').convert('RGBA').crop((0,0,362,362));kb=k.getchannel('A').getbbox();k=k.crop(kb);k.thumbnail((35,35),Image.Resampling.LANCZOS);board.paste(k,(x+205,y+130-k.height),k)
y=790;d.text((20,y),'Relics / native 20 px, 32 px, 64 px / dark and ivory backgrounds',fill='#eee4ca')
for i,s in enumerate(spec[7:]):
 x=20+i*390;d.text((x,y+28),s['id'],fill='#eee4ca');r=s['region'];im=Image.open(s['path'].replace('res://','')).convert('RGBA').crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
 for j,bg in enumerate(['#243a31','#eee4ca']):
  yy=y+60+j*100;d.rectangle((x,yy,x+360,yy+90),fill=bg)
  for dx,size in [(10,20),(90,32),(190,64)]:
   t=im.copy();t.thumbnail((size,size),Image.Resampling.LANCZOS);board.paste(t,(x+dx+(size-t.width)//2,yy+10+64-t.height),t)
board.save(p/'native-comparison.png')
print('10 alpha-valid originals; regions/spec and native board written')
