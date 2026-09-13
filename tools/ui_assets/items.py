"""Reproducible item-art preparation and editable ComfyUI preset builder.

No generation requests, dependency downloads or background removal occur here.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/ui-items'
RUNTIME = ROOT / 'prototype/assets/ui-icons/items'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def workflows():
    spec = read(ART / 'prompts.json')
    for index, item in enumerate(spec['items']):
        graph = read(ROOT / 'tools/asset_pipeline/templates/concept.json')
        ui = read(ROOT / 'art/environment/comfy-workflow.json')
        blocks = {'1': 'Telos industrial science-fiction equipment inventory icon.',
                  '2': spec['style'].replace('genuinely transparent background with alpha', 'plain solid neutral grey background for subsequent cutout'),
                  '3': item['subject'], '4': 'One centered object, square composition, generous safe margins, three-quarter view. No text, frame or UI.',
                  '5': 'Soft upper-left lighting, worn steel and brass, muted ochre, selective highlights, quiet surface detail.'}
        for key, value in blocks.items():
            graph[key]['inputs']['value'] = value
        graph['15']['inputs'].update(width=1024, height=1024)
        graph['16']['inputs']['seed'] = 9102600 + index
        graph['18']['inputs']['filename_prefix'] = 'Telos/UI_Items/' + item['id']
        for node in ui['nodes']:
            key = str(node['id'])
            if key in blocks:
                node['widgets_values'] = [blocks[key]]
            elif key == '15':
                node['widgets_values'] = [1024, 1024, 1]
            elif key == '16':
                node['widgets_values'][0:2] = [9102600 + index, 'fixed']
            elif key == '18':
                node['widgets_values'] = [graph['18']['inputs']['filename_prefix']]
            elif key == '19':
                node['widgets_values'] = ['TELOS ITEM: ' + item['label'] + '. Edit subject node 3. Generate, review, then run cutout. Do not bake rarity borders into the image.']
        ui['extra'] = {'Telos': {'asset_id': item['id'], 'stage': 'item-concept'}}
        write(ART / 'workflows' / (item['id'] + '.api.json'), graph)
        write(ART / 'workflows' / (item['id'] + '.json'), ui)
    for suffix in ('.api.json', '.json'):
        source = ROOT / ('art/side-view/workflows/06_cutout' + suffix)
        if source.exists():
            target = read(source)
            if suffix == '.api.json':
                target['5']['inputs']['filename_prefix'] = 'Telos/UI_Items/cutouts/item'
            else:
                for node in target['nodes']:
                    if node['type'] == 'SaveImage':
                        node['widgets_values'] = ['Telos/UI_Items/cutouts/item']
            write(ART / 'workflows' / ('cutout' + suffix), target)
    print('Built 9 ComfyUI UI/API pairs and available cutout templates; not submitted to a server.')

def prepare():
    spec = read(ART / 'prompts.json')
    records = {}
    gallery = Image.new('RGB', (960, 900), '#17212b')
    draw = ImageDraw.Draw(gallery)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for index, item in enumerate(spec['items']):
        source = ART / 'sources' / (item['id'] + '.png')
        with Image.open(source) as original:
            im = original.convert('RGBA')
        alpha = im.getchannel('A')
        if alpha.getextrema()[0] != 0 or alpha.getextrema()[1] == 0:
            raise ValueError(f'{source}: genuine transparency required; use cutout first')
        bounds = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
        if not bounds:
            raise ValueError(f'{source}: empty image')
        icon = im.crop(bounds)
        icon.thumbnail((194, 194), Image.Resampling.LANCZOS)
        output = Image.new('RGBA', (256, 256))
        output.alpha_composite(icon, ((256-icon.width)//2, (256-icon.height)//2))
        path = RUNTIME / (item['id'] + '.png')
        output.save(path)
        records[item['id']] = {'path': 'res://assets/ui-icons/items/' + path.name,
            'source': str(source.relative_to(ROOT)).replace('\\', '/'),
            'source_sha256': digest(source), 'sha256': digest(path),
            'canvas': [256, 256], 'visible_bounds': list(output.getchannel('A').getbbox()),
            'prompt': item['prompt'], 'generator': spec['generator']}
        x, y = (index % 3)*320, (index//3)*300
        gallery.paste(output, (x+32, y), output)
        draw.text((x+16, y+248), item['label'], fill='white')
        for j, size in enumerate([32, 48, 64]):
            small = output.resize((size, size), Image.Resampling.LANCZOS)
            gallery.paste(small, (x+12+j*85, y+270-size//2), small)
    write(RUNTIME / 'manifest.json', {'version': 1, 'items': records})
    gallery.save(ART / 'gallery.png')
    print('Prepared 9 transparent 256px icons, SHA-256 manifest and native-size gallery.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['workflows', 'prepare'])
    args = parser.parse_args()
    workflows() if args.command == 'workflows' else prepare()
