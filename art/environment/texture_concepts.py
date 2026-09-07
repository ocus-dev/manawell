"""Generate material swatches with the existing local ComfyUI graph."""
import json, pathlib, urllib.request
ROOT=pathlib.Path(__file__).resolve().parent
OUT=ROOT/'textures'; OUT.mkdir(exist_ok=True)
base=json.loads((ROOT/'comfy-api.json').read_text())
jobs={}
for index,(name,description) in enumerate({
 'concrete': 'Full-frame orthographic material swatch of weathered cool grey industrial concrete. Subtle broad mottling, fine aggregate, faint dark hairline cracks, restrained dusty patches and small surface pits. Quiet low contrast. Flat evenly lit surface, no large joints, no tiles or grid, no perspective, no objects, no shadows, no vignette. Seamless repeating material, continuous detail across edges. Hand-painted gouache surface treatment for an industrial Japanese OVA game background. Grey stone, not blue.',
 'ochre_paint': 'Full-frame orthographic material swatch of worn muted yellow ochre paint on industrial steel. Broad calm areas of faded ochre paint with sparse dark charcoal paint chips and restrained reddish rust spotting. Brushed hand-painted gouache style, crisp graphic chips, no glossy photographic highlights. Flat uniform diffuse lighting, no perspective, no object outlines, no cast shadows, no text, no bevels, no vignette. Seamless repeating material. Most of the surface is intact paint; wear remains sparse.'
}.items()):
 p=json.loads(json.dumps(base))
 p['1']['inputs']['value']='Game material surface study, coherent hand-painted industrial palette.'
 p['2']['inputs']['value']='Flat texture image, even illumination, no baked directional lighting.'
 p['3']['inputs']['value']=description
 p['4']['inputs']['value']='Square texture fills the image edge to edge.'
 p['5']['inputs']['value']='Restrained material detail readable from a distant gameplay camera.'
 p['15']['inputs'].update(width=1024,height=1024)
 p['16']['inputs']['seed']=9062040+index
 p['18']['inputs']['filename_prefix']='Telos/BrokenFoundry/'+name+'_v1'
 (OUT/(name+'-api.json')).write_text(json.dumps(p,indent=2))
 req=urllib.request.Request('http://127.0.0.1:8188/prompt',data=json.dumps({'prompt':p}).encode(),headers={'Content-Type':'application/json'})
 jobs[name]=json.load(urllib.request.urlopen(req))
(OUT/'jobs.json').write_text(json.dumps(jobs,indent=2))
print(json.dumps(jobs))
