"""Build the continuous Home backdrop layers from home_city.png (2026-10-03).

Usage: python make_layers.py <path/to/home_city.png> <output folder>
Needs numpy + pillow. Writes:
- home_sky_far.png    sky + mountains (rows 0-430). The original, continued to
                      2508 px by image quilting (strips of the painting joined
                      along a minimum-error cut with a 40 px blend). The sun
                      only appears once, at the start. Scrolls slowly (parallax).
- home_ground_start.png  treeline + wall + tarmac (rows 345-941) of the original.
- home_ground_tile.png   the same rows from x=400 on, mirrored then plain. After
                      the start piece it repeats edge to edge; every join is
                      mirror-continuous. The sun glare (x<400) stays in the start.
The ground images are opaque only below the top of the runway and its barrier
wall (found per column with GrabCut, 2026-10-03); above that they are fully
transparent, so the trees and fog come only from the sky layer (no see-through
band where two copies of the trees overlapped). The sky layer reaches down to
row 470 to sit behind that edge; the runway/wall pixels in it are painted over
(inpainted) first, so no stray bits of wall show above the runway.
"""
import sys
import numpy as np
import cv2
from scipy.ndimage import median_filter
from PIL import Image

SKY_BOTTOM = 470
FADE_TOP = 345          # ground images start at this row (transparent above the edge)
EDGE_BAND = (370, 480)  # rows searched for the runway/wall top
TILE_FROM_X = 400
SKY_WIDTH = 2508          # 1920 px in the 1280x720 canvas
SKY_SEED = 1

def min_cut(e):
    h, o = e.shape
    c = e.copy(); back = np.zeros((h, o), int)
    for y in range(1, h):
        prev = c[y - 1]
        stack = np.vstack([np.r_[np.inf, prev[:-1]], prev, np.r_[prev[1:], np.inf]])
        k = stack.argmin(0)
        c[y] += stack[k, np.arange(o)]; back[y] = np.arange(o) + k - 1
    cut = np.zeros(h, int); cut[-1] = c[-1].argmin()
    for y in range(h - 1, 0, -1):
        cut[y - 1] = back[y, cut[y]]
    return cut

def quilt(img, out_w, B, O, rng, x_min, feather, K=3):
    h, W, _ = img.shape
    out = np.zeros((h, out_w, 3), np.float32)
    out[:, :W] = img; pos = W; prev = W - B; log = []
    while pos < out_w:
        ov = out[:, pos - O:pos]
        errs = sorted((((img[:, x:x + O] - ov) ** 2).sum(2).mean(), x) for x in range(x_min, W - B, 4))
        cands = [(e, x) for e, x in errs if abs(x - prev) > B * 0.75 and all(abs(x - u) > B * 0.45 for u in log[-2:])][:K]
        if not cands:
            cands = [(e, x) for e, x in errs if abs(x - prev) > B * 0.75][:K]
        _, x = cands[rng.integers(len(cands))]
        cut = min_cut(((img[:, x:x + O] - ov) ** 2).sum(2))
        n = min(B, out_w - (pos - O))
        patch = img[:, x:x + n].copy()
        t = np.clip((np.arange(O)[None, :] - cut[:, None] + feather / 2) / float(feather), 0, 1)[..., None]
        patch[:, :O] = ov * (1 - t) + patch[:, :O] * t
        out[:, pos - O:pos - O + n] = patch
        log.append(x); pos = pos - O + n; prev = x
    return out

def runway_top(src):
    """Per column: the first row of the runway or its barrier wall."""
    y0, y1 = EDGE_BAND
    band = np.ascontiguousarray(src[y0:y1])
    h, w, _ = band.shape
    m = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    m[:15] = cv2.GC_BGD
    m[60:] = cv2.GC_PR_FGD
    m[85:] = cv2.GC_FGD
    cv2.setRNGSeed(0)
    cv2.grabCut(cv2.cvtColor(band, cv2.COLOR_RGB2BGR), m, None, np.zeros((1, 65)), np.zeros((1, 65)), 8, cv2.GC_INIT_WITH_MASK)
    f = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    f = cv2.morphologyEx(f, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    _, lab = cv2.connectedComponents(f)
    keep = np.isin(lab, np.unique(lab[-1])) & (lab > 0)
    top = np.full(w, h)
    for x in range(w):
        y = h - 1
        while y >= 0 and keep[y, x]:
            y -= 1
        top[x] = y + 1
    return median_filter(top, size=9, mode='nearest') + y0

def ground_alpha(top, rows):
    """Opaque below the edge with a 2 px soft line, transparent above."""
    y = np.arange(rows)[:, None] + FADE_TOP
    return (np.clip((y - top[None, :] + 1) / 2.0, 0, 1) * 255).astype(np.uint8)

def main(src_path, out_dir):
    src = np.asarray(Image.open(src_path).convert('RGB'))
    top = runway_top(src)
    # Sky source: paint over the runway and wall so none of it shows above the
    # ground layer when the sky scrolls at a different speed.
    sky_src = src[:SKY_BOTTOM].copy()
    hole = np.zeros(sky_src.shape[:2], np.uint8)
    for x in range(src.shape[1]):
        hole[max(0, top[x] - 3):, x] = 255
    sky_src = cv2.inpaint(sky_src, hole, 7, cv2.INPAINT_TELEA)
    sky = quilt(sky_src.astype(np.float32), SKY_WIDTH, B=520, O=220,
                rng=np.random.default_rng(SKY_SEED), x_min=380, feather=40)
    Image.fromarray(sky.clip(0, 255).astype(np.uint8)).save(f'{out_dir}/home_sky_far.png')
    g = src[FADE_TOP:]
    Image.fromarray(np.dstack([g, ground_alpha(top, g.shape[0])])).save(f'{out_dir}/home_ground_start.png')
    t = g[:, TILE_FROM_X:]
    tt = top[TILE_FROM_X:]
    pair = np.concatenate([t[:, ::-1], t], 1)
    pair_top = np.concatenate([tt[::-1], tt])
    Image.fromarray(np.dstack([pair, ground_alpha(pair_top, pair.shape[0])])).save(f'{out_dir}/home_ground_tile.png')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '.')
