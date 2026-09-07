"""Prepare the selected V04 environment layers for the fixed 1280x720 scene."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / 'art/side-view/environment'
DESTINATION = ROOT / 'prototype/assets/side-view/environment'
REVIEW_ROOT = SOURCE_ROOT / 'reviews'
LOGICAL_SIZE = (1280, 720)
GROUND_Y = 540
LANE_HEIGHT = LOGICAL_SIZE[1] - GROUND_Y
LANE_CROP = (0, 148, 1536, 364)
BACKDROP_EDGE_Y = 414
RISER_HEIGHT = GROUND_Y - BACKDROP_EDGE_Y
ALPHA_EXPECTATION = 'opaque'

BACKDROP_SOURCE = SOURCE_ROOT / '07-backdrop-01/result.png'
LANE_SOURCE = SOURCE_ROOT / '08-lane-01/result.png'
DRESSING_SOURCE = SOURCE_ROOT / '09-dressing-01/result.png'


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def _relative(path):
    return str(Path(path).relative_to(ROOT)).replace('\\', '/') if path else None


def _save_new(image, path):
    if path.exists():
        raise FileExistsError(f'refusing to overwrite prepared output: {path}')
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format='PNG')


def prepare_backdrop():
    image = Image.open(BACKDROP_SOURCE).convert('RGB')
    prepared = image.resize(LOGICAL_SIZE, Image.Resampling.LANCZOS)
    lane_material = Image.open(LANE_SOURCE).convert('RGB').crop(LANE_CROP)
    riser = lane_material.resize((LOGICAL_SIZE[0], RISER_HEIGHT), Image.Resampling.LANCZOS)
    prepared.paste(riser, (0, BACKDROP_EDGE_Y))
    draw = ImageDraw.Draw(prepared)
    draw.line((0, GROUND_Y - 2, prepared.width, GROUND_Y - 2), fill='#303d42', width=2)
    output = DESTINATION / 'backdrop.png'
    _save_new(prepared, output)
    return {
        'layer': 'backdrop',
        'source_path': _relative(BACKDROP_SOURCE),
        'source_sha256': digest(BACKDROP_SOURCE),
        'output_path': _relative(output),
        'output_sha256': digest(output),
        'original_dimensions': list(image.size),
        'prepared_dimensions': list(prepared.size),
        'transform': {
            'operation': 'exact_resize_then_lane_material_riser_cover',
            'from': list(image.size),
            'to': list(LOGICAL_SIZE),
            'crop': None,
            'covered_backdrop_edge_y': BACKDROP_EDGE_Y,
            'riser_height': RISER_HEIGHT,
            'riser_source_crop': list(LANE_CROP),
            'riser_resize_to': [LOGICAL_SIZE[0], RISER_HEIGHT],
            'perspective_warp': False,
        },
        'logical_placement': [0, 0],
        'logical_bounds': [0, 0, LOGICAL_SIZE[0], LOGICAL_SIZE[1]],
        'draw_order': 0,
        'filtering': 'Godot linear texture filtering; one authored resize for fixed plate',
        'alpha_expectation': ALPHA_EXPECTATION,
        'rationale': 'Selected V04 candidate; the competing painted retaining-wall edge is covered from y=414 to y=540 with the same lane material before the prepared lane begins.',
    }


def prepare_lane():
    image = Image.open(LANE_SOURCE).convert('RGB')
    cropped = image.crop(LANE_CROP)
    prepared = cropped.resize((LOGICAL_SIZE[0], LANE_HEIGHT), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(prepared)
    draw.rectangle((0, 0, prepared.width - 1, 3), fill='#b58d4a')
    draw.line((0, 4, prepared.width, 4), fill='#303d42', width=2)
    output = DESTINATION / 'lane.png'
    _save_new(prepared, output)
    return {
        'layer': 'service_lane',
        'source_path': _relative(LANE_SOURCE),
        'source_sha256': digest(LANE_SOURCE),
        'output_path': _relative(output),
        'output_sha256': digest(output),
        'original_dimensions': list(image.size),
        'prepared_dimensions': list(prepared.size),
        'transform': {
            'operation': 'central_crop_then_resize',
            'crop': list(LANE_CROP),
            'resize_to': [LOGICAL_SIZE[0], LANE_HEIGHT],
            'perspective_warp': False,
        },
        'logical_placement': [0, GROUND_Y],
        'logical_bounds': [0, GROUND_Y, LOGICAL_SIZE[0], LANE_HEIGHT],
        'top_edge_y': GROUND_Y,
        'draw_order': 1,
        'filtering': 'Godot linear texture filtering; non-tiling fixed-width strip',
        'alpha_expectation': ALPHA_EXPECTATION,
        'authored_geometry': {'top_trim_pixels': 4, 'top_edge_color': '#b58d4a', 'edge_shadow_color': '#303d42'},
        'rationale': 'Covers the backdrop lower edge from y=540 through the bottom without introducing a second floating floor plane.',
    }


def _font(size):
    try:
        from PIL import ImageFont
        return ImageFont.truetype('consola.ttf', size)
    except OSError:
        from PIL import ImageFont
        return ImageFont.load_default()


ACTORS = [
    ('hero', 'prototype/assets/side-view/hero.png', 80, 230),
    ('pursuer', 'prototype/assets/side-view/pursuer.png', 58, 420),
    ('harvester', 'prototype/assets/side-view/harvester.png', 190, 640),
    ('breaker', 'prototype/assets/side-view/breaker.png', 112, 820),
    ('ranged', 'prototype/assets/side-view/ranged.png', 90, 1030),
]


def _actor_layer(path, visible_height, center_x):
    image = Image.open(ROOT / path).convert('RGBA')
    bounds = image.getchannel('A').getbbox()
    if bounds is None:
        raise ValueError(f'actor has no visible alpha: {path}')
    scale = visible_height / (bounds[3] - bounds[1])
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    resized_bounds = resized.getchannel('A').getbbox()
    return resized, (round(center_x - (resized_bounds[0] + resized_bounds[2]) / 2), GROUND_Y - resized_bounds[3])


def compose_review(debug=False):
    backdrop = Image.open(DESTINATION / 'backdrop.png').convert('RGBA')
    lane = Image.open(DESTINATION / 'lane.png').convert('RGBA')
    backdrop.alpha_composite(lane, (0, GROUND_Y))
    overlay = Image.new('RGBA', LOGICAL_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    if debug:
        draw.line((0, GROUND_Y, LOGICAL_SIZE[0], GROUND_Y), fill=(244, 210, 98, 230), width=2)
        for x in (96, 1184):
            draw.line((x, GROUND_Y - 44, x, GROUND_Y + 26), fill=(244, 210, 98, 220), width=2)
            draw.text((x + 6, GROUND_Y - 64), f'ENTRY {x}', fill=(255, 237, 159, 255), font=_font(16))
        draw.text((22, 20), 'V05 PREPARED ENVIRONMENT DEBUG', fill=(255, 240, 194, 255), font=_font(18))
        draw.text((22, 44), 'ground y=540 | logical canvas 1280x720 | dressing omitted', fill=(224, 231, 224, 255), font=_font(13))
    for name, path, height, x in ACTORS:
        actor, position = _actor_layer(path, height, x)
        backdrop.alpha_composite(actor, position)
        if debug:
            draw.text((x - 34, GROUND_Y + 10), name, fill=(255, 240, 194, 255), font=_font(14))
    if debug:
        backdrop = Image.alpha_composite(backdrop, overlay)
    output = REVIEW_ROOT / ('v05-prepared-debug.png' if debug else 'v05-prepared-composition.png')
    _save_new(backdrop.convert('RGB'), output)
    return _relative(output)


def prepare():
    for path in (BACKDROP_SOURCE, LANE_SOURCE, DRESSING_SOURCE):
        if not path.is_file():
            raise FileNotFoundError(path)
    DESTINATION.mkdir(parents=True, exist_ok=True)
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    layers = [prepare_backdrop(), prepare_lane()]
    layers.append({
        'layer': 'edge_dressing',
        'source_path': _relative(DRESSING_SOURCE),
        'source_sha256': digest(DRESSING_SOURCE),
        'output_path': None,
        'original_dimensions': list(Image.open(DRESSING_SOURCE).size),
        'prepared_dimensions': None,
        'transform': None,
        'logical_placement': None,
        'logical_bounds': None,
        'draw_order': 2,
        'filtering': None,
        'alpha_expectation': 'omitted; source remains opaque and was not sent through 06_cutout',
        'rationale': 'Omitted because the selected backdrop already has strong lower pipework; adding a prop would compete with actor feet, warnings, and the harvester.',
    })
    reviews = [compose_review(), compose_review(debug=True)]
    manifest = {
        'version': 1,
        'logical_canvas': list(LOGICAL_SIZE),
        'ground_y': GROUND_Y,
        'selected_candidate': '07-backdrop-01',
        'layers': layers,
        'actor_contract': {
            'source_manifest': 'prototype/assets/side-view/side-view-assets.json',
            'visible_heights_unchanged': {name: height for name, _path, height, _x in ACTORS},
            'ground_anchor_rule': 'Actors retain their existing visual-child anchors; environment preparation does not alter actor transforms or collisions.',
        },
        'visual_config': {
            'backdrop_tint': [1.0, 1.0, 1.0, 1.0],
            'backdrop_contrast': 1.0,
            'lane_tint': [1.0, 1.0, 1.0, 1.0],
            'reversible': True,
            'rationale': 'Neutral preparation preserves the selected V04 palette; later scene tuning should remain configuration-only.',
        },
        'reviews': [{'path': path, 'sha256': digest(ROOT / path)} for path in reviews],
        'runtime_note': 'Prepared files are runtime-local and intentionally not imported into gameplay during V05.',
    }
    manifest_path = DESTINATION / 'environment-manifest.json'
    _save_new(Image.new('RGBA', (1, 1)), DESTINATION / '.write-probe.png')
    (DESTINATION / '.write-probe.png').unlink()
    if manifest_path.exists():
        raise FileExistsError(f'refusing to overwrite manifest: {manifest_path}')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        result = prepare()
        print('Prepared environment manifest:', DESTINATION / 'environment-manifest.json')
        print('Reviews:', ', '.join(item['path'] for item in result['reviews']))