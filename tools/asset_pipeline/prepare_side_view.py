"""Prepare reviewed side-view cutouts without changing source artwork."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / 'prototype/assets/side-view'
PREPARED = ROOT / 'art/side-view/prepared'
ALPHA_THRESHOLD = 8
SAFETY_PADDING = 4

ASSETS = {
    'hero': {
        'source': 'art/side-view/pilots/hero-01/result.png',
        'cutout': 'art/side-view/pilots/hero-cutout-01/result.png',
        'height': 80,
    },
    'harvester': {
        'source': 'art/side-view/pilots/02_harvester/result.png',
        'cutout': 'art/side-view/prepared/harvester-cutout/result.png',
        'height': 190,
    },
    'pursuer': {
        'source': 'art/side-view/pilots/03_enemy_pursuer-biological/result.png',
        'cutout': 'art/side-view/prepared/pursuer-cutout/result.png',
        'height': 58,
    },
    'breaker': {
        'source': 'art/side-view/pilots/04_enemy_breaker-biological/result.png',
        'cutout': 'art/side-view/prepared/breaker-cutout/result.png',
        'height': 112,
        'note': 'Source has an angled pose rather than a strict side profile.',
    },
    'ranged': {
        'source': 'art/side-view/pilots/05_enemy_ranged-biological/result.png',
        'cutout': 'art/side-view/prepared/ranged-cutout/result.png',
        'height': 90,
        'note': 'Source has a lifted leg; the lowest planted foot is the ground anchor.',
    },
}


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def alpha_bounds(image, threshold=ALPHA_THRESHOLD):
    alpha = image.getchannel('A')
    if alpha.getextrema() == (0, 0):
        raise ValueError('image is fully transparent')
    if alpha.getextrema() == (255, 255):
        raise ValueError('image is fully opaque; run the cutout workflow first')
    bounds = alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()
    if bounds is None:
        raise ValueError(f'image has no alpha at or above threshold {threshold}')
    return bounds


def prepare_image(cutout, output, anchor_override=None, padding=SAFETY_PADDING):
    cutout = Path(cutout)
    output = Path(output)
    with Image.open(cutout) as loaded:
        image = loaded.convert('RGBA')
    if image.getchannel('A').getextrema() == (255, 255):
        raise ValueError(f'{cutout} is opaque; refusing to import a failed cutout')
    visible = alpha_bounds(image)
    left = max(0, visible[0] - padding)
    top = max(0, visible[1] - padding)
    right = min(image.width, visible[2] + padding)
    bottom = min(image.height, visible[3] + padding)
    crop = (left, top, right, bottom)
    prepared = image.crop(crop)
    if anchor_override is None:
        anchor = ((visible[0] + visible[2] - 1) // 2 - left, visible[3] - 1 - top)
    else:
        if not (left <= anchor_override[0] < right and top <= anchor_override[1] < bottom):
            raise ValueError('ground anchor override must fall inside the crop')
        anchor = (anchor_override[0] - left, anchor_override[1] - top)
    output = Path(output)
    if output.exists():
        raise FileExistsError(f'refusing to overwrite existing derived output: {output}')
    output.parent.mkdir(parents=True, exist_ok=True)
    prepared.save(output, format='PNG')
    return {
        'original_dimensions': [image.width, image.height],
        'crop_rectangle': list(crop),
        'visible_bounds': list(visible),
        'ground_anchor': list(anchor),
        'derived_dimensions': [prepared.width, prepared.height],
        'visible_height': visible[3] - visible[1],
    }


def prepare_assets(assets=ASSETS, destination=DESTINATION, prepared_root=PREPARED):
    destination = Path(destination)
    prepared_root = Path(prepared_root)
    manifest = {
        'alpha_threshold': ALPHA_THRESHOLD,
        'safety_padding': SAFETY_PADDING,
        'right_facing_convention': 'artwork faces right; mirror the visual child for left-facing presentation',
        'assets': [],
    }
    for asset_id, spec in assets.items():
        source = ROOT / spec['source']
        cutout = ROOT / spec['cutout']
        output = destination / f'{asset_id}.png'
        if not source.is_file():
            raise FileNotFoundError(source)
        if not cutout.is_file():
            raise FileNotFoundError(cutout)
        details = prepare_image(cutout, output)
        entry = {
            'asset_id': asset_id,
            'source_path': spec['source'],
            'source_sha256': digest(source),
            'cutout_path': spec['cutout'],
            'cutout_sha256': digest(cutout),
            'derived_png': str(output.relative_to(ROOT)).replace('\\', '/'),
            'derived_sha256': digest(output),
            'initial_visible_height': spec['height'],
            **details,
        }
        if 'note' in spec:
            entry['known_source_characteristic'] = spec['note']
        manifest['assets'].append(entry)
    destination.mkdir(parents=True, exist_ok=True)
    manifest_path = destination / 'side-view-assets.json'
    if manifest_path.exists():
        raise FileExistsError(f'refusing to overwrite existing manifest: {manifest_path}')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


def checkerboard(size, cell=16):
    image = Image.new('RGB', size, '#d9d9d9')
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill='#f4f4f4')
    return image


def review_sheet(manifest, output=PREPARED / 'review-sheet.png'):
    entries = manifest['assets']
    width, height = 1500, 780
    sheet = Image.new('RGB', (width, height), '#20252a')
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), 'Side-view sprite review: edge crops and proposed display scale', fill='white')
    baseline = 650
    column_width = width // len(entries)
    for index, entry in enumerate(entries):
        image = Image.open(ROOT / entry['derived_png']).convert('RGBA')
        x = index * column_width + 20
        draw.text((x, 52), entry['asset_id'], fill='white')
        edge = image.crop((0, 0, min(image.width, 160), min(image.height, 160)))
        for background, y in ((('#f5f5f5', 82)), (('#30353a', 250))):
            panel = Image.new('RGBA', (160, 150), background)
            panel.alpha_composite(edge.resize((min(160, edge.width), min(150, edge.height))))
            sheet.paste(panel.convert('RGB'), (x, y))
        display_height = entry['initial_visible_height']
        scale = display_height / max(1, entry['visible_height'])
        display = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
        display_x = x + (column_width - 40 - display.width) // 2
        display_y = baseline - entry['ground_anchor'][1] * scale
        backdrop = checkerboard((column_width - 40, baseline - 420))
        sheet.paste(backdrop, (x, 420))
        sheet.paste(display, (display_x, round(display_y)), display)
        draw.line((x, baseline, x + column_width - 40, baseline), fill='#e2b04a', width=2)
    output = Path(output)
    if output.exists():
        raise FileExistsError(f'refusing to overwrite existing review sheet: {output}')
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format='PNG')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--review', action='store_true')
    args = parser.parse_args()
    manifest = prepare_assets() if args.prepare else json.loads((DESTINATION / 'side-view-assets.json').read_text())
    if args.review:
        print('Saved', review_sheet(manifest))
    if args.prepare:
        print('Saved', DESTINATION / 'side-view-assets.json')


if __name__ == '__main__':
    main()