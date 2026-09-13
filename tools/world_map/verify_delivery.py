"""Read-only delivery checks and a compact candidate contact sheet."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from maps import OUT,THEMES,read_json,validate,digest,client,native,font
from PIL import Image,ImageDraw

schemas=client().get('/object_info')
for p in (OUT/'workflows').glob('*.api.json'):
    g=read_json(p)
    client().validate(g)
    native(g,schemas,p.stem)
    ui=read_json(p.with_name(p.name.replace('.api.json','.json')))
    nodes={n['id']:n for n in ui['nodes']}
    for lid,src,slot,dst,idx,t in ui['links']:
        assert lid in nodes[src]['outputs'][slot]['links']
        assert nodes[dst]['inputs'][idx]['link']==lid
    print('PASS workflow:',p.name)
sheet=Image.new('RGB',(1280,3*400),'#18242c')
for i,name in enumerate(THEMES):
    out=OUT/'candidates'/name
    job=read_json(out/'job.json');prep=read_json(out/'preparation.json')
    assert job['status']=='complete'
    assert job['source_sha256']==digest(out/'source.png')==prep['source_sha256']
    assert prep['master_sha256']==digest(out/'master.png')
    assert prep['layout_sha256']==digest(out/'layout.json')
    validate(read_json(out/'layout.json'))
    assert Image.open(out/'master.png').size==(2048,1152)
    for col,file in enumerate(['master.png','overlay.png']):
        im=Image.open(out/file);im.thumbnail((640,360))
        sheet.paste(im,(col*640,i*400+40))
    ImageDraw.Draw(sheet).text((16,i*400+10),name+' / clean art + draft route',font=font(20),fill='white')
    print('PASS candidate:',name,'seed',job['spec']['seed'],'job',job['prompt_id'])
sheet.save(OUT/'candidate-contact-sheet.png')
