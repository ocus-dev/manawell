"""Build editable local ComfyUI side-view presets; run resumable pilot jobs."""
import argparse
import copy
import json
import uuid
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, read_json, write_json
from comfy import Comfy

OUT = ROOT / 'art/side-view/workflows'
ACTOR_PRESETS = {
    '01_hero': ('One piloted humanoid industrial combat mech, full body, facing RIGHT. Compact upright red armored silhouette, broad shoulder plates, charcoal articulated knees, heavy boots, one small cyan visor. Practical compact forearm gun pointing right, separated arms and legs in a neutral combat-ready standing pose. No human outside the cockpit. Clear foot contact at one baseline.', 'Muted oxide red armor, charcoal joints, small cyan friendly identification light.', 80),
    '02_harvester': ('One stationary industrial mana harvester, complete machine viewed from its SIDE. Wide low anchored base, central heavy vertical extraction cylinder, two external pressure tanks, thick visible pipes, a protective overhead gantry and one analog gauge cluster. Strong stepped silhouette, functional mechanisms, front service access kept clear. No operator, no surrounding building. Quiet idle state, no exhaust covering the outline.', 'Muted ochre painted steel, charcoal base, small cyan mana chamber. Yellow maintenance markings without readable text.', 190),
    '03_enemy_pursuer': ('One alien pursuer creature, full body, strict SIDE PROFILE facing RIGHT. Low lean stalking quadruped, long forward head, angular hooked forelimbs, tightly grouped organic shell plates, tense runner silhouette, unmistakably alive rather than a robot. All limbs contained in frame, feet on one baseline. No rider, no armor equipment.', 'Desaturated bone and dark plum organic shell, small amber hostile eyes. No friendly cyan lights.', 58),
    '04_enemy_breaker': ('One alien siege breaker creature, full body, strict SIDE PROFILE facing RIGHT. Broad heavy hunched body, massive downward hammer forelimbs for smashing machinery, short planted hind legs, layered mineral shell on its back. Tall blunt head and broad weight-bearing silhouette. Feet planted on one baseline. No equipment, no scenery.', 'Dark umber and stone-grey shell, restrained rust-orange fissures and amber eyes. No friendly cyan.', 112),
    '05_enemy_ranged': ('One alien ranged spitter creature, full body, strict SIDE PROFILE facing RIGHT. Tall narrow tripod-like organic legs, raised arched neck and forward-pointing tubular biological snout, distinct swollen throat reservoir. Clear spaces between legs. Idle poised firing stance, mouth closed, no projectile or smoke. Feet on one baseline. No manufactured weapon.', 'Muted violet-grey shell and pale bone limbs, small amber throat reservoir to support a later windup glow. No friendly cyan.', 90),
}
ENVIRONMENT_PRESETS = {
    '07_environment_backdrop': {
        'subject': 'A wide fixed-camera Broken Foundry side-view arena background: distant stepped brutalist foundry buildings, cooling stacks, rear gantries, thick pipes and muted industrial infrastructure arranged only along the rear and far edges. Leave a broad quiet central combat lane and clear machine area. No actors, machines, weapons, UI, lettering, signage text or foreground occlusion.',
        'finish': 'Blue-grey overcast ambient light, muted ochre painted steel, charcoal reinforced concrete, restrained cyan instrumentation far in the distance. Low-contrast atmospheric depth behind the open lane, soft upper-left light, large calm value shapes, readable silhouettes over the center. No dramatic vignette.',
        'composition': 'Strict level SIDE-ON orthographic game background, 16:9 wide landscape plate, camera parallel to the service deck at actor mid-height. Horizon and distant architecture remain stable and nearly horizontal. Keep the central machine position around x=640 clear, leave open space from x=96 to x=1184, and reserve the lower service lane for a later separate deck layer. No isometric tilt, no elevated courtyard view, no perspective floor plane, no actors, no machine, no UI, no lettering.',
        'world': 'A physically grounded retro-industrial foundry frontier: reinforced concrete, painted steel, blackened pipework, cooling equipment, ducts, gantries and practical maintenance structures. Broad engineered forms, sparse meaningful detail, visible function and historical repairs. No sleek futuristic surfaces.',
        'width': 1536,
        'height': 864,
        'seed': 9072107,
    },
    '08_environment_lane': {
        'subject': 'A broad horizontal service deck material for a retro-industrial foundry: worn reinforced concrete and inset metal plates, subtle seams, patched edges, restrained oil stains and scuffed maintenance wear. Quiet broad surfaces with no object standing on the deck.',
        'finish': 'Charcoal concrete, faded blue-grey metal, small muted ochre maintenance accents, restrained upper-left illumination and soft painted OVA texture. Keep contrast low enough for dark and bright actors to remain readable.',
        'composition': 'Wide 3:1 horizontal material source, level side-on view with the deck surface presented as a calm broad band. No painted fake holes, no obstacles, no deep cracks crossing the play lane, no strong baked cast shadows, no perspective convergence, no text, no lettering, no actors, no machine. This is a material source, not a promised seamless tile.',
        'world': 'A physically grounded retro-industrial foundry service deck built from reinforced concrete, heavy rubber edge seals and blackened steel plates. Functional wear and repair history, broad quiet forms, no decorative clutter.',
        'width': 1536,
        'height': 512,
        'seed': 9072108,
    },
    '09_environment_dressing': {
        'subject': 'One fully visible isolated low industrial foundry prop: a compact pipe housing and bundled cable service box, low enough to sit at the arena edge. Strong simple silhouette, practical brackets and a few maintenance seams. No building, no floor, no other props, no actors.',
        'finish': 'Muted ochre painted steel, charcoal rubber and blackened pipework with restrained cyan service light. Worn but readable, soft upper-left painted illumination, clear edge contrast.',
        'composition': 'One isolated low industrial prop centered on an opaque uniform neutral light-grey background, fully visible with generous margin on every edge. Level side view, no dramatic perspective, no cast ground shadow, no text, no lettering, no UI, no duplicate objects. The neutral background is for the existing cutout stage.',
        'world': 'A physically grounded retro-industrial foundry service object made from painted steel, cast aluminum, heavy rubber seals and blackened conduit. Functional detail clustered around brackets and connections; broad quiet panels elsewhere.',
        'width': 1024,
        'height': 1024,
        'seed': 9072109,
    },
}
PRESETS = {**ACTOR_PRESETS, **ENVIRONMENT_PRESETS}
COMPOSITION = ('Production concept for a 2D SIDE-VIEW game sprite. Orthographic side elevation at subject mid-height; camera level, no top-down view, no isometric view, no three-quarter turn, no foreshortening. ONE isolated complete subject centered on a perfectly uniform light grey background. Entire silhouette including feet, antennae and weapon visible with at least 12 percent empty margin on every edge. No floor line, cast ground shadow, environment, text, labels, sprite sheet, turnaround, duplicate subject or cropped extremities. Soft upper-left studio illumination, restrained painted shading. Opaque background for a separate segmentation pass; do not draw a checkerboard.')

def build():
    OUT.mkdir(parents=True, exist_ok=True)
    base = read_json(ROOT / 'tools/asset_pipeline/templates/concept.json')
    ui_base = read_json(ROOT / 'art/environment/comfy-workflow.json')
    for index, (name, data) in enumerate(PRESETS.items()):
        if name in ACTOR_PRESETS and (OUT / (name + '.json')).exists() and (OUT / (name + '.api.json')).exists():
            continue
        if name in ACTOR_PRESETS:
            subject, finish, height = data
            config = {
                'subject': subject,
                'finish': finish,
                'composition': COMPOSITION,
                'world': None,
                'width': 1024,
                'height': 1024,
                'seed': 9072026 + index,
                'stage': 'side-view-concept',
                'suggested_height_px': height,
            }
        else:
            config = {**data, 'stage': 'side-view-environment'}
        graph, ui = copy.deepcopy(base), copy.deepcopy(ui_base)
        for key, value in {'1': config['world'] or graph['1']['inputs']['value'], '3': config['subject'], '4': config['composition'], '5': config['finish']}.items():
            graph[key]['inputs']['value'] = value
        if name in ACTOR_PRESETS and 'enemy' in name:
            graph['1']['inputs']['value'] = ('Native alien fauna inhabiting a retro-industrial science-fiction world. This subject is entirely BIOLOGICAL: matte chitin, rough bone, leathery hide, tendons, muscular limbs and naturally grown irregular shell plates. No manufactured armor, metal panels, bolts, hydraulics, robotic joints, cables, guns or machinery on its body. Broad organic primary masses, readable functional anatomy and clear negative spaces. Restrained surface detail, strong weight and material texture. Keep the graphic painted OVA rendering of the surrounding industrial world while contrasting its manufactured machines.')
        graph['15']['inputs'].update(width=config['width'], height=config['height'])
        graph['16']['inputs']['seed'] = config['seed']
        graph['18']['inputs']['filename_prefix'] = 'Telos/SideView/' + name
        for node in ui['nodes']:
            key = str(node['id'])
            if key in ('1', '2', '3', '4', '5'):
                node['widgets_values'] = [graph[key]['inputs']['value']]
            elif key == '15':
                node['widgets_values'] = [config['width'], config['height'], 1]
            elif key == '16':
                node['widgets_values'][0] = graph[key]['inputs']['seed']
                node['widgets_values'][1] = 'fixed'
            elif key == '18':
                node['widgets_values'] = [graph[key]['inputs']['filename_prefix']]
            elif key == '19':
                node['widgets_values'] = [f'TELOS SIDE VIEW: {name}. Edit SUBJECT (3), COMPOSITION (4), FINISH (5), seed (16). Keep the shared renderer and model nodes. Generate one still, review the layer contract, and record the output.']
            ui['extra'] = {'Telos': {key: value for key, value in config.items() if key not in ('world', 'subject', 'composition', 'finish')}}
        write_json(OUT / (name + '.api.json'), graph)
        write_json(OUT / (name + '.json'), ui)
    cutout = {
        '1': {'class_type': 'LoadImage', 'inputs': {'image': 'choose-approved-concept.png'}},
        '2': {'class_type': 'Trellis2RemoveBackground', 'inputs': {'image': ['1', 0], 'low_vram': True}},
        '3': {'class_type': 'InvertMask', 'inputs': {'mask': ['2', 1]}},
        '4': {'class_type': 'JoinImageWithAlpha', 'inputs': {'image': ['1', 0], 'alpha': ['3', 0]}},
        '5': {'class_type': 'SaveImage', 'inputs': {'images': ['4', 0], 'filename_prefix': 'Telos/SideView/cutouts/asset'}},
    }
    write_json(OUT / '06_cutout.api.json', cutout)
    # Build a small native UI graph using installed node schemas.
    cfg = read_json(Path(__file__).with_name('config.json'))
    client = Comfy(cfg['concept_url'])
    info = client.get('/object_info')
    nodes, links = [], []
    for key, entry in cutout.items():
        schema = info[entry['class_type']]
        node = {'id': int(key), 'type': entry['class_type'], 'pos': [int(key)*320, 200], 'size': [290, 220], 'flags': {}, 'order': int(key)-1, 'mode': 0, 'inputs': [], 'outputs': [{'name': name, 'type': typ, 'links': []} for name, typ in zip(schema['output_name'], schema['output'])], 'properties': {'Node name for S&R': entry['class_type']}, 'widgets_values': []}
        for field, value in entry['inputs'].items():
            if isinstance(value, list):
                typ = info[cutout[value[0]]['class_type']]['output'][value[1]]
                link = len(links)+1
                links.append([link, int(value[0]), value[1], int(key), len(node['inputs']), typ])
                node['inputs'].append({'name': field, 'type': typ, 'link': link})
            else:
                node['widgets_values'].append(value)
        if entry['class_type'] == 'LoadImage':
            node['widgets_values'].append('image')
        nodes.append(node)
    for link, source, slot, *_ in links:
        nodes[source-1]['outputs'][slot]['links'].append(link)
    write_json(OUT / '06_cutout.json', {'version': 0.4, 'last_node_id': 5, 'last_link_id': len(links), 'nodes': nodes, 'links': links, 'groups': [], 'config': {}, 'extra': {}})
    for path in OUT.glob('*.api.json'):
        client.validate(read_json(path))
    print(f'Built and validated {len(PRESETS) + 1} workflow pairs against installed nodes/models:', OUT)

def run(preset, output, image=None):
    directory = Path(output).resolve()
    if not directory.is_relative_to(ROOT):
        raise ValueError('Run output must be inside this repository')
    directory.mkdir(parents=True, exist_ok=True)
    cfg = read_json(Path(__file__).with_name('config.json'))
    client = Comfy(cfg['concept_url'])
    record_path = directory / 'job.json'
    if record_path.exists():
        record = read_json(record_path)
        if record['preset'] != preset:
            raise ValueError('Use a new output folder for a different preset')
        graph = read_json(directory / 'api.json')
    else:
        graph = read_json(OUT / (preset + '.api.json'))
        if preset == '06_cutout':
            if not image:
                raise ValueError('--image is required for cutout')
            graph['1']['inputs']['image'] = client.upload(image, 'telos-side-' + uuid.uuid4().hex + '.png')
        record = {'preset': preset, 'token': uuid.uuid4().hex}
        write_json(directory / 'api.json', graph)
        write_json(record_path, record)
    if record.get('status') == 'complete':
        print('Already complete:', directory / 'result.png')
        return
    result = client.run(graph, directory, 'generate', record, lambda: write_json(record_path, record), 1800)
    client.download_image(result, '5' if preset == '06_cutout' else '18', directory / 'result.png')
    record['status'] = 'complete'
    write_json(record_path, record)
    print('Saved', directory / 'result.png')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--run', choices=[*PRESETS, '06_cutout'])
    parser.add_argument('--out')
    parser.add_argument('--image')
    args = parser.parse_args()
    if args.build:
        build()
    if args.run:
        if not args.out:
            parser.error('--run requires --out')
        run(args.run, args.out, args.image)
