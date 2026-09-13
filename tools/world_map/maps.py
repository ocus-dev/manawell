"""Draft act-map authoring, local Comfy generation, and deterministic overlays."""
import argparse
import copy
import hashlib
import json
import math
import sys
import uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'asset_pipeline'))
from common import ROOT,read_json,write_json
from comfy import Comfy
from PIL import Image,ImageDraw,ImageFont

OUT=ROOT/'art/world-map'
CONFIG=read_json(ROOT/'tools/asset_pipeline/config.json')
THEMES={
 'A_valley': 'An immense inland industrial valley seen from very high above, the entire region fills the composition. A broad winding dry river basin leads from lower-left scrap fields through central pumping terraces to an enormous distant circular furnace citadel in the upper right. Broken railway viaducts bridge ravines. Small scattered service buildings establish enormous landscape scale. Three districts: dusty salvage foothills at left, ochre pumping works in the middle, dark clinker mountains and the crown furnace at upper right. Vast quiet terrain between industrial clusters. No close foreground building.',
 'B_coast': 'An immense crescent-shaped industrial coast seen from very high above, the whole region fills the composition. Slate-blue sea and a broad estuary occupy the lower right, with rust-colored headlands and small dry docks at lower left, fragmented pumping islands and causeways through the center, and an enormous fortress furnace on a rocky peninsula at upper right. Tiny ships and long breakwaters establish enormous scale. Three districts: abandoned salvage port at left, ochre tidal pumping marshes in the middle, dark fortified furnace headland at upper right. Large expanses of calm water and exposed rock between industrial clusters.',
 'C_terraces': 'An immense stepped open-pit industrial mountain region seen from very high above, the whole region fills the composition. Deep broad terraced excavation bowls with tiny industrial equipment begin at lower left, climb across immense switchback retaining walls and pumping shelves through the center, and reach a colossal crown-shaped furnace fortress on a high upper-right plateau. Tiny conveyors and narrow rail bridges establish enormous scale. Three districts: low rust-red salvage quarry at left, ochre pressure terraces in the middle, charcoal upland furnace stronghold at upper right. Large quiet stone shelves between small industrial clusters.',
}
POSITIONS=[[.10,.77],[.23,.67],[.19,.46],[.35,.32],[.47,.49],[.56,.70],[.69,.58],[.77,.38],[.87,.21]]
NAMES=['Scrap Approach','Intake Well','Broken Viaduct','Cinder Crossing','Pressure Well','Rail Graveyard','Furnace Rampart','Crown Well','The Crown Furnace']
TYPES=['monster','well','monster','monster','well','monster','monster','well','boss']

def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def client():return Comfy(CONFIG['concept_url'])
def local(p):
    p=Path(p).resolve()
    if not p.is_relative_to(ROOT):raise ValueError('Output must be inside the repository')
    return p

def validate(m):
    ns=m['nodes']; ids=[n['id'] for n in ns]
    assert len(ns)==9 and len(set(ids))==9,'Exactly nine unique nodes required'
    assert [sum(n['type']==t for n in ns) for t in ('well','monster','boss')]==[3,5,1]
    wells=[n['well_id'] for n in ns if n['type']=='well']
    assert len(set(wells))==3 and all(wells)
    for i,n in enumerate(ns):
        assert n['prerequisites']==([] if i==0 else [ids[i-1]]),'Route must be a connected sequential DAG'
        assert len(n['position'])==2 and all(math.isfinite(v) and .06<=v<=.94 for v in n['position'])
        assert n['encounter_key'] and n['display_name']
        assert (n.get('well_id') is not None)==(n['type']=='well')
    assert ns[-1]['type']=='boss' and m['boss_requires']==ids[:-1]
    assert len(m['paths'])==8
    for i,path in enumerate(m['paths']):
        assert (path['from'],path['to'])==(ids[i],ids[i+1])
        assert path['points'][0]==ns[i]['position'] and path['points'][-1]==ns[i+1]['position']
        assert all(len(p)==2 and all(math.isfinite(v) and 0<=v<=1 for v in p) for p in path['points'])
    # Target hit regions: 44 logical pixels at 1280x720, with margin.
    for i,a in enumerate(ns):
        for b in ns[i+1:]:
            assert math.hypot((a['position'][0]-b['position'][0])*1280,(a['position'][1]-b['position'][1])*720)>60
    return True

def initialize():
    OUT.mkdir(parents=True,exist_ok=True)
    ns=[];well=0
    for i,(name,kind,pos) in enumerate(zip(NAMES,TYPES,POSITIONS),1):
        n={'id':f'act_01_node_{i:02d}','display_name':name,'type':kind,'position':pos,'prerequisites':[] if i==1 else [f'act_01_node_{i-1:02d}'],'encounter_key':f'draft.act_01.{kind}_{i:02d}'}
        if kind=='well':well+=1;n['well_id']=f'well_{well}'
        ns.append(n)
    m={'schema_version':1,'act_id':'act_01','display_name':'Broken Foundry','status':'draft_design_not_runtime','layout_revision':'route-01','theme':'Ruined industrial valley; raw mana','master_size':[2048,1152],'generation_size':[1536,864],'display':'contain','safe_margin':.06,'nodes':ns,'boss_requires':[n['id'] for n in ns[:-1]],'paths':[{'from':a['id'],'to':b['id'],'points':[a['position'],b['position']]} for a,b in zip(ns,ns[1:])],'next_act_id':None}
    validate(m)
    path=OUT/'act_01.draft.json'
    if path.exists() and read_json(path)!=m:raise ValueError('Existing draft differs; preserve its edits')
    write_json(path,m)
    base=read_json(ROOT/'tools/asset_pipeline/templates/concept.json')
    prompts={'world':base['1']['inputs']['value'],'style':base['2']['inputs']['value'],'theme':'Broken Foundry, first act of a retro-industrial science fiction campaign. Muted ochre steel, rust-red earth, charcoal concrete, blue-grey atmospheric distance, restrained cyan raw-mana seams. Overcast daylight, deliberate quiet surfaces, coherent painted geography.','composition':'High aerial oblique regional atlas painting, wide 16:9 landscape. NOT a single arena, NOT a street-level scene, NOT a floating miniature diorama. Geographic landforms span the full frame. Tiny structures occupy only a fraction of the terrain. Traversable districts wind from lower left through center to a dominant boss furnace landmark around 87 percent across and 21 percent down. Keep landmarks within a 6 percent safe margin. Distant ridges continue beyond the regional boundary; no decorative frame.','exclusions':'Clean scenery only. No words, lettering, labels, numbers, map pins, route lines, dotted trails, node circles, icons, UI, compass rose, legends, characters, giant foreground machines, watermarks or baked progression states. Physical railways and pipes are allowed as landscape infrastructure, not highlighted game paths.','alternatives':THEMES}
    pp=OUT/'prompt-blocks.json'
    if not pp.exists():write_json(pp,prompts)
    overlay(Image.new('RGB',(2048,1152),'#28313a'),m,OUT/'layout-sketch.png','DRAFT ROUTE / no scenery')
    print('M01 draft validated; nine-node layout sketch created',flush=True)

def graph(candidate,seed,reference=None,denoise=.55):
    p=read_json(OUT/'prompt-blocks.json')
    g=read_json(ROOT/'tools/asset_pipeline/templates/concept.json')
    for key,value in {'1':p['world'],'2':p['style'],'3':p['alternatives'][candidate],'4':p['composition'],'5':p['theme']+' '+p['exclusions']}.items():g[key]['inputs']['value']=value
    g['15']['inputs'].update(width=1536,height=864)
    g['16']['inputs']['seed']=seed
    g['18']['inputs']['filename_prefix']='Telos/WorldMap/'+candidate
    if reference:
        g['20']={'class_type':'LoadImage','inputs':{'image':reference}}
        g['21']={'class_type':'ImageScale','inputs':{'image':['20',0],'upscale_method':'lanczos','width':1536,'height':864,'crop':'disabled'}}
        g['15']={'class_type':'VAEEncode','inputs':{'pixels':['21',0],'vae':['12',0]}}
        g['16']['inputs']['denoise']=denoise
    return g

def native(g,schemas,title):
    nodes=[];links=[]
    for order,(key,entry) in enumerate(g.items()):
        s=schemas[entry['class_type']]
        n={'id':int(key),'type':entry['class_type'],'title':{'1':'WORLD / materials','2':'STYLE / rendering','3':'GEOGRAPHY / candidate','4':'COMPOSITION / scale','5':'THEME / exclusions'}.get(key,entry['class_type']),'pos':[(order//4)*460,(order%4)*400],'size':[430,350],'flags':{},'order':order,'mode':0,'inputs':[],'outputs':[{'name':name,'type':t,'links':[]} for name,t in zip(s['output_name'],s['output'])],'properties':{'Node name for S&R':entry['class_type']},'widgets_values':[]}
        fields={**s['input'].get('required',{}),**s['input'].get('optional',{})}
        assert set(s['input'].get('required',{}))<=set(entry['inputs'])
        for name,definition in fields.items():
            if name not in entry['inputs']:continue
            v=entry['inputs'][name]
            if isinstance(v,list):
                actual=schemas[g[v[0]]['class_type']]['output'][v[1]]
                assert actual==definition[0],(key,name,actual,definition[0])
                lid=len(links)+1
                links.append([lid,int(v[0]),v[1],int(key),len(n['inputs']),actual])
                n['inputs'].append({'name':name,'type':actual,'link':lid})
            else:
                if isinstance(definition[0],list):assert v in definition[0]
                n['widgets_values'].append(v)
                if len(definition)>1 and definition[1].get('control_after_generate'):n['widgets_values'].append('fixed')
        if entry['class_type']=='LoadImage':n['widgets_values'].append('image')
        nodes.append(n)
    byid={n['id']:n for n in nodes}
    for lid,src,slot,dst,idx,t in links:
        byid[src]['outputs'][slot]['links'].append(lid)
        assert byid[dst]['inputs'][idx]['link']==lid
    note='TELOS WORLD MAP / '+title+'\nEdit WORLD, STYLE, GEOGRAPHY, COMPOSITION and THEME blocks. Seed fixed. Concept size: EmptyLatentImage; revision size: ImageScale. Defaults 1536x864; deliver 2048x1152 by uniform resampling. Revision uses loaded image -> resize -> VAEEncode -> KSampler latent input, denoise 0.55. Supply a clean 16:9 map, never a UI overlay. Low denoise retains more geography, high denoise changes it. No promise of exact landmark preservation. SaveImage is clean art only. Route/node overlays and all game status stay separate. Design approval is still pending.'
    nodes.append({'id':99,'type':'MarkdownNote','pos':[-470,0],'size':[440,650],'flags':{},'order':len(nodes),'mode':0,'inputs':[],'outputs':[],'properties':{},'widgets_values':[note]})
    return {'version':.4,'last_node_id':99,'last_link_id':len(links),'nodes':nodes,'links':links,'groups':[],'config':{},'extra':{'Telos':{'title':title}}}

def build(reference):
    c=client()
    dest=OUT/'workflows';dest.mkdir(exist_ok=True)
    im=Image.open(reference)
    if abs(im.width/im.height-16/9)>1e-5:raise ValueError('Revision reference must be 16:9')
    remote=c.upload(reference,'telos_worldmap_'+digest(reference)[:16]+'.png')
    s=c.get('/object_info')
    for name,g in [('01_act_concept',graph('A_valley',9073101)),('02_reference_revision',graph('A_valley',9073104,remote))]:
        c.validate(g);ui=native(g,s,name)
        write_json(dest/(name+'.api.json'),g);write_json(dest/(name+'.json'),ui)
    write_json(dest/'reference-provenance.json',{'path':str(Path(reference).resolve()),'sha256':digest(reference),'remote':remote})
    print('Two native/API pairs validated and built',flush=True)

def font(size):return ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size)
def overlay(background,m,path,title):
    validate(m)
    im=background.convert('RGBA');w,h=im.size
    layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer)
    scale=w/1280
    xy=lambda p:(round(p[0]*w),round(p[1]*h))
    for edge in m['paths']:
        pts=[xy(p) for p in edge['points']]
        d.line(pts,fill=(10,18,23,210),width=round(7*scale))
        d.line(pts,fill=(226,204,153,230),width=round(2*scale))
    for i,n in enumerate(m['nodes'],1):
        x,y=xy(n['position']);r=round(16*scale)
        col={'well':'#78d5db','monster':'#e8d6ab','boss':'#f19876'}[n['type']]
        if n['type']=='well':d.rectangle((x-r,y-r,x+r,y+r),fill='#16242b',outline=col,width=round(2*scale))
        elif n['type']=='boss':d.polygon([(x,y-r-4),(x+r+4,y),(x,y+r+4),(x-r-4,y)],fill='#16242b',outline=col,width=round(2*scale))
        else:d.ellipse((x-r,y-r,x+r,y+r),fill='#16242b',outline=col,width=round(2*scale))
        d.text((x,y),str(i),font=font(round(15*scale)),anchor='mm',fill=col)
        label=n['display_name'];f=font(round(13*scale));box=d.textbbox((x,y+r+7),label,font=f,anchor='mt')
        d.rectangle((box[0]-5,box[1]-3,box[2]+5,box[3]+3),fill=(14,23,29,215))
        d.text((x,y+r+7),label,font=f,anchor='mt',fill='white')
    d.rectangle((0,0,w,round(53*scale)),fill=(14,23,29,220))
    d.text((round(20*scale),round(15*scale)),title+' | DRAFT / 3 wells, 5 combat, 1 boss',font=font(round(18*scale)),fill='#eee6d7')
    d.text((round(20*scale),h-round(28*scale)),'Circle: combat   Square: well   Diamond: boss   /   Design layout only; no campaign state',font=font(round(13*scale)),fill='white',stroke_width=1,stroke_fill='#16242b')
    Image.alpha_composite(im,layer).convert('RGB').save(path)

def run(candidate,out,seed,reference=None,denoise=.55):
    out=local(out);out.mkdir(parents=True,exist_ok=True)
    c=client();record_path=out/'job.json'
    spec={'candidate':candidate,'seed':seed,'reference_sha256':digest(reference) if reference else None,'denoise':denoise if reference else 1.,'prompt_sha256':digest(OUT/'prompt-blocks.json')}
    if record_path.exists():
        record=read_json(record_path)
        if record['spec']!=spec:raise ValueError('Changed inputs require new output directory')
        g=read_json(out/'api.json')
    else:
        remote=None
        if reference:
            im=Image.open(reference)
            if abs(im.width/im.height-16/9)>1e-5:raise ValueError('Supply clean 16:9 reference')
            remote=c.upload(reference,'telos_map_'+uuid.uuid4().hex+'.png')
        g=graph(candidate,seed,remote,denoise)
        record={'token':uuid.uuid4().hex,'spec':spec}
        write_json(out/'api.json',g);write_json(record_path,record)
    if record.get('status')=='failed':raise RuntimeError('Prior job failed; inspect history and use new directory after fixing')
    if record.get('status')=='complete':
        assert digest(out/'source.png')==record['source_sha256'],'Source changed'
        print('Verified completed render:',out,flush=True);return
    result=c.run(g,out,'generate',record,lambda:write_json(record_path,record),1800)
    c.download_image(result,'18',out/'source.png')
    record.update(status='complete',source_sha256=digest(out/'source.png'),models={k:v['inputs'] for k,v in g.items() if v['class_type'] in ('UNETLoader','CLIPLoader','VAELoader')})
    write_json(record_path,record)
    print('Generated:',out/'source.png',flush=True)

def prepare(out):
    out=local(out);record=read_json(out/'job.json')
    assert record['status']=='complete' and digest(out/'source.png')==record['source_sha256']
    source=Image.open(out/'source.png').convert('RGB')
    if source.size!=(1536,864):raise ValueError('Unexpected model dimensions')
    master=source.resize((2048,1152),Image.Resampling.LANCZOS)
    master.save(out/'master.png')
    lp=out/'layout.json'
    if not lp.exists():write_json(lp,read_json(OUT/'act_01.draft.json'))
    m=read_json(lp);validate(m)
    overlay(master,m,out/'overlay.png',record['spec']['candidate']+' / Broken Foundry')
    overlay(master.resize((1280,720),Image.Resampling.LANCZOS),m,out/'overlay-1280.png',record['spec']['candidate'])
    write_json(out/'preparation.json',{'source_sha256':digest(out/'source.png'),'master_sha256':digest(out/'master.png'),'source_size':source.size,'master_size':master.size,'method':'uniform Lanczos 4/3, no cropping or stretching','layout_sha256':digest(lp),'design_approved':False})
    print('Prepared clean master + separate overlays:',out,flush=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='cmd',required=True)
    s.add_parser('init')
    b=s.add_parser('build');b.add_argument('--reference',required=True)
    r=s.add_parser('run');r.add_argument('--candidate',choices=THEMES,required=True);r.add_argument('--out',required=True);r.add_argument('--seed',type=int,required=True);r.add_argument('--reference');r.add_argument('--denoise',type=float,default=.55)
    r=s.add_parser('prepare');r.add_argument('--out',required=True)
    a=p.parse_args()
    if a.cmd=='init':initialize()
    elif a.cmd=='build':build(a.reference)
    elif a.cmd=='prepare':prepare(a.out)
    else:
        if not 0<a.denoise<=1 or not 0<=a.seed<2**64:p.error('Invalid denoise or seed')
        run(a.candidate,a.out,a.seed,a.reference,a.denoise)
if __name__=='__main__':main()
