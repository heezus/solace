import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
p=Path('docs/art/tellings/portraits'); ids=['portrait_kin_elder','portrait_sela','portrait_bloom']; spec=[]
b=Image.new('RGB',(1140,1120),'#21332f');d=ImageDraw.Draw(b)
d.text((20,12),'Solace portraits / 320x400 and 96x120 / dark and ivory alpha check',fill='#eee4ca')
for i,stem in enumerate(ids):
 f=Path('art/rendered/portraits')/(stem+'.png'); im=Image.open(f).convert('RGBA'); src=p/'sources'/(stem+'.png'); original=Image.open(src)
 assert im.size==(1024,1280),(stem,im.size)
 assert im.getchannel('A').getextrema()==(0,255)
 box=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
 spec.append(dict(id=stem,path='res://'+str(f),size=list(im.size),source_size=list(original.size),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),alpha_extrema=[0,255],region=[box[0],box[1],box[2]-box[0],box[3]-box[1]],export='aspect-preserving sips -Z 1280'))
 x=20+i*375; d.text((x,42),stem,fill='#eee4ca')
 for j,bg in enumerate(['#21332f','#eee4ca']):
  y=70+j*490; d.rectangle((x,y,x+340,y+420),fill=bg)
  t=im.resize((320,400),Image.Resampling.LANCZOS);b.paste(t,(x+10,y+10),t)
  t=im.resize((96,120),Image.Resampling.LANCZOS);b.paste(t,(x+235,y+310),t)
 d.text((x,1060),'320x400 + 96x120',fill='#eee4ca')
b.save(p/'native-comparison.png');(p/'spec.json').write_text(json.dumps(spec,indent=2)+'\n')
