"""Read-only native comparison; source branches are art dependencies, not engine inputs."""
import ast,hashlib,io,json,re,subprocess
from pathlib import Path
from PIL import Image,ImageDraw

HERE=Path('docs/art/research-ironfall-livewire')
def blob(path,ref=None):
 if Path(path).exists(): return Path(path).read_bytes()
 return subprocess.check_output(['git','show',ref+':'+path]) if ref else Path(path).read_bytes()
def group(path,ref=None):
 return {s['id']:dict(s,source_ref=ref) for s in json.loads(blob(path,ref))}
tiles=group('docs/art/ironfall/tiles/spec.json')
buildings=group('docs/art/ironfall/buildings/spec.json')
items=group('docs/art/ironfall/items/spec.json')
live=group('docs/art/livewire/buildings/spec.json','codex/livewire-buildings')
steam=group('docs/art/ironfall/stage3/spec.json','codex/ironfall-stage3-art')
sources={
 'coal_seams':dict(tiles['coal_seam'],region=tiles['coal_seam']['regions'][0]),
 'ironstone':dict(tiles['iron_hills'],region=tiles['iron_hills']['regions'][0]),
 'bloomery':buildings['bloomery'],'boiler':steam['boiler'],'beast_pen':steam['beast_pen'],
 'iron_tools':items['iron_tools'],'rails':dict(steam['rail'],region=[720,274,340,340]),
 'shard_lamps':dict(steam['shard_lamp_lit'],region=[450,28,360,525]),'blast_furnace':steam['forge'],
 'shard_boiler':steam['shard_boiler'],'steel':items['steel'],
 'power_poles':dict(live['power_pole'],region=[330,38,580,400]),'order_board':live['order_board'],'generator':live['generator'],
 'arc_lamps':dict(live['arc_lamp'],region=[360,24,540,470]),'factory_floor':live['factory_floor'],'scorcher':live['scorcher'],
 'shard_dynamo':live['shard_dynamo'],
}
rendered=Path('scripts/rendered_art.gd').read_text()
regions=ast.literal_eval(rendered.split('const REGIONS := ',1)[1].split('\n\nconst BloomLook',1)[0])
single=ast.literal_eval(rendered.split('const SINGLE_BUILDINGS := ',1)[1].split('\n## The tint',1)[0])
def old_sprite(icon):
 special={'kith':('walk',1),'wanderer':('research-landmarks',3),'field':('plants',6),'dwelling':('buildings',0),'tile_road':('crossings-v2',0),'item_copper_ore':('items',12),'item_bronze_tools':('items',17)}
 atlas,index=special.get(icon,single.get(icon,(None,None)))
 assert atlas is not None,icon
 return dict(path='res://art/rendered/'+atlas+'.png',region=regions[atlas][index])
specs=[]
for era in ['ironfall','livewire']:
 text=Path('scripts/data/'+era+'/techs.gd').read_text()
 for const,body in re.findall(r'const (\w+) := \{(.*?)(?=\nconst |\Z)',text,re.S):
  name=re.search(r'"name": "([^"]+)"',body).group(1)
  old=re.search(r'"icon": "([^"]+)"',body).group(1)
  id=const.lower()
  if id in sources:
   s=sources[id].copy(); kind='reused painted asset'
  else:
   p='art/rendered/research/'+id+'.png'; raw=blob(p); im=Image.open(io.BytesIO(raw)).convert('RGBA'); a=im.getchannel('A')
   assert a.getextrema()==(0,255),id
   b=a.point(lambda v:255 if v>8 else 0).getbbox(); b=(max(0,b[0]-2),max(0,b[1]-2),min(im.width,b[2]+2),min(im.height,b[3]+2))
   s=dict(path='res://'+p,region=[b[0],b[1],b[2]-b[0],b[3]-b[1]],source_size=list(im.size),source_ref=None); kind='new dedicated symbol'
  raw=blob(s['path'].replace('res://',''),s.get('source_ref')); im=Image.open(io.BytesIO(raw))
  specs.append(dict(tech_id=id,name=name,era=era,previous_icon=old,suggested_icon='research_'+id,path=s['path'],region=s['region'],source_size=list(im.size),source_ref=s.get('source_ref'),sha256=hashlib.sha256(raw).hexdigest(),kind=kind))
assert len(specs)==30
(HERE/'spec.json').write_text(json.dumps(specs,indent=2)+'\n')
def cropped(s):
 im=Image.open(io.BytesIO(blob(s['path'].replace('res://',''),s.get('source_ref')))).convert('RGBA'); r=s['region']
 return im.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
for era in ['ironfall','livewire']:
 entries=[s for s in specs if s['era']==era]
 board=Image.new('RGB',(1200,70+((len(entries)+3)//4)*230),'#263e35'); d=ImageDraw.Draw(board)
 d.text((20,16),era.title()+' research / old 24 px | proposed 24, 34, 48 px + 96 px inspection',fill='#eee4ca')
 d.text((20,36),'Documentation composite; reused sources read directly from their focused art branches.',fill='#eee4ca')
 for i,s in enumerate(entries):
  x=15+(i%4)*300; y=75+(i//4)*230
  d.text((x,y),s['name'],fill='#eee4ca')
  old=cropped(old_sprite(s['previous_icon'])); new=cropped(s)
  for dx,size,im in [(0,24,old),(48,24,new),(96,34,new),(154,48,new),(60,96,new)]:
   t=im.copy(); t.thumbnail((size,size),Image.Resampling.LANCZOS); by=y+70 if size<96 else y+195
   board.paste(t,(x+dx+(size-t.width)//2,by-t.height),t)
   d.text((x+dx,by+5),('old ' if dx==0 else '')+str(size),fill='#eee4ca')
 board.save(HERE/(era+'-native-review.png'))
print('Mapped',len(specs),'techs;',sum(s['kind']=='new dedicated symbol' for s in specs),'new symbols')
