"""Make a deterministic V04 backdrop review with the approved actor sprites."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ACTORS = [
    ('hero', 'assets/side-view/hero.png', 80, 230),
    ('pursuer', 'assets/side-view/pursuer.png', 58, 420),
    ('harvester', 'assets/side-view/harvester.png', 190, 640),
    ('breaker', 'assets/side-view/breaker.png', 112, 820),
    ('ranged', 'assets/side-view/ranged.png', 90, 1030),
]
LOGICAL_SIZE = (1280, 720)
GROUND_Y = 540


def _font(size):
    try:
        return ImageFont.truetype('consola.ttf', size)
    except OSError:
        return ImageFont.load_default()


def _actor_layer(path, visible_height, center_x, scale):
    image = Image.open(ROOT / 'prototype' / path).convert('RGBA')
    alpha = image.getchannel('A')
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f'Actor has no visible alpha: {path}')
    factor = visible_height / (bounds[3] - bounds[1]) * scale
    resized = image.resize((round(image.width * factor), round(image.height * factor)), Image.Resampling.LANCZOS)
    resized_bounds = resized.getchannel('A').getbbox()
    x = round(center_x * scale - (resized_bounds[0] + resized_bounds[2]) / 2)
    y = round(GROUND_Y * scale - resized_bounds[3])
    return resized, (x, y)


def review(backdrop, output):
    source = Image.open(backdrop).convert('RGBA')
    scale = source.width / LOGICAL_SIZE[0]
    canvas = source.copy()
    overlay = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    lane_y = round(GROUND_Y * scale)
    draw.rectangle((0, lane_y, canvas.width, canvas.height), fill=(40, 48, 49, 42))
    draw.line((0, lane_y, canvas.width, lane_y), fill=(244, 210, 98, 220), width=max(1, round(2 * scale)))
    for x in (96, 1184):
        position = round(x * scale)
        draw.line((position, lane_y - round(44 * scale), position, lane_y + round(26 * scale)), fill=(244, 210, 98, 210), width=max(1, round(2 * scale)))
        draw.text((position + round(6 * scale), lane_y - round(64 * scale)), f'ENTRY {x}', fill=(255, 237, 159, 255), font=_font(round(16 * scale)))
    for name, path, height, x in ACTORS:
        actor, position = _actor_layer(path, height, x, scale)
        overlay.alpha_composite(actor, position)
        draw.text((round((x - 34) * scale), lane_y + round(10 * scale)), name, fill=(255, 240, 194, 255), font=_font(round(14 * scale)))
    draw.text((round(22 * scale), round(20 * scale)), 'V04 STATIC ACTOR COMPOSITION REVIEW', fill=(255, 240, 194, 255), font=_font(round(18 * scale)))
    draw.text((round(22 * scale), round(44 * scale)), 'ground y=540  |  logical canvas 1280x720  |  provisional lane overlay', fill=(224, 231, 224, 255), font=_font(round(13 * scale)))
    canvas = Image.alpha_composite(canvas, overlay).convert('RGB')
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    print(f'Saved review: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backdrop', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    review(args.backdrop, args.out)