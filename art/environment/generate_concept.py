"""Reuse the PNG-embedded ComfyUI workflow; save reproducible inputs in this repo."""
import json, pathlib, urllib.request
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/environment'
metadata = Image.open(ROOT / 'concept_art/03_jungle_complex_00001_.png').info
prompt = json.loads(metadata['prompt'])
workflow = json.loads(metadata['workflow'])
blocks = {
    '3': 'Broken Foundry: an abandoned heavy industrial mana extraction courtyard. Broad square cracked concrete combat floor with a small cyan geological fissure at its center. The center is open and empty for a game encounter. Large cooling cylinders, rust-orange pump housings, black thick pipes, ventilation grilles, concrete retaining walls and yellow safety markings cluster around the perimeter only. Behind the courtyard stand stepped brutalist foundry buildings and twin smokestacks. Asymmetric stacks of machine scrap at the edges. No people, no weapons, no interface.',
    '4': 'Elevated three-quarter gameplay camera looking down into the complete courtyard. Wide landscape composition, readable modular geometry suitable for modeling a low-poly game environment. Clear open foreground and center; tall structures only at the rear and lateral edges. The small central fissure is the focus. One cohesive environment concept painting.',
    '5': 'Cool overcast blue-grey daylight, warm muted ochre industrial equipment, chipped painted metal and charcoal concrete. Restrained luminous cyan mana fissure. Quiet abandoned frontier worksite, strong large shadow shapes and restrained atmospheric haze behind the buildings, clear visibility across the play area.',
}
for key, value in blocks.items():
    prompt[key]['inputs']['value'] = value
    for node in workflow['nodes']:
        if str(node['id']) == key:
            node['widgets_values'] = [value]
prompt['16']['inputs']['seed'] = 9062026
prompt['18']['inputs']['filename_prefix'] = 'Telos/BrokenFoundry/concept_v1'
for node in workflow['nodes']:
    if node['id'] == 16:
        node['widgets_values'][0] = 9062026
    if node['id'] == 18:
        node['widgets_values'][0] = 'Telos/BrokenFoundry/concept_v1'
    if node['id'] == 19:
        node['widgets_values'] = ['Telos Broken Foundry environment concept. Seed 9062026. Open 28m gameplay floor; tall perimeter dressing. This is a modeling reference, not a 3D reconstruction.']
workflow['extra'] = {'Telos': {'asset': 'Broken Foundry', 'seed': 9062026}}
(OUT / 'comfy-workflow.json').write_text(json.dumps(workflow, indent=2), encoding='utf8')
(OUT / 'comfy-api.json').write_text(json.dumps(prompt, indent=2), encoding='utf8')
request = urllib.request.Request('http://127.0.0.1:8188/prompt', data=json.dumps({'prompt': prompt, 'extra_data': {'extra_pnginfo': {'workflow': workflow}}}).encode(), headers={'Content-Type': 'application/json'})
result = json.load(urllib.request.urlopen(request))
(OUT / 'comfy-job.json').write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
