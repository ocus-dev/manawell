# Usage (from the manawell folder): python art/side-view/environment/drill/render_auger.py
#   [harvester.png] [out_dir]  -> out_dir/f00..f11.png + previews. Needs numpy, pillow,
#   opencv-contrib-python. The atlas is these frames at half size, 4x3, in
#   prototype/assets/side-view/animations/harvester_idle/.
# Turns the drill's painted auger: each frame moves the painting's own auger
# pixels down along the screw (one pitch per revolution), so the frames keep the
# art's exact brushwork. The auger is cut out of the painting with GrabCut, the
# space behind it is painted in, and the moving copy is blended over it.
import os, sys
import numpy as np, cv2
from PIL import Image

SRC_PATH = sys.argv[1] if len(sys.argv) > 1 else 'prototype/assets/side-view/harvester.png'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'auger_frames'
N = 12
S = np.array(Image.open(SRC_PATH).convert('RGBA')).astype(np.float32)
H, W = S.shape[:2]
RGB = S[..., :3]; A = S[..., 3] / 255.0

# The two visible stretches of the screw, in harvester.png pixels.
REGIONS = {
    'upper': dict(box=(442, 656, 546, 706), out=(446, 652), src=(446, 652), pitch=80.0, cx=625.0, r_top=72.0, r_bot=72.0, win=(509.0, 589.0), shadow=0.45),
    'lower': dict(box=(938, 1080, 530, 716), out=(944, 1052), src=(944, 1052), pitch=64.0, cx=625.0, r_top=86.0, r_bot=74.0, win=(966.0, 1030.0), shadow=0.3, end=1049.0, end_tilt=4.0, shaft_r=27.0),
}

def grabcut(box, cx):
    y0, y1, x0, x1 = box
    rgb = RGB[y0:y1, x0:x1].astype(np.uint8); a = A[y0:y1, x0:x1]
    h, w = a.shape
    m = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    m[:, 8:w - 8] = cv2.GC_PR_FGD
    m[:, :3] = cv2.GC_BGD; m[:, w - 3:] = cv2.GC_BGD
    c = int(cx - x0); m[:, c - 14:c + 14] = cv2.GC_FGD
    m[a < 0.08] = cv2.GC_BGD
    bgd = np.zeros((1, 65)); fgd = np.zeros((1, 65))
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), m, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
    fg = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg)
    keep = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    fg = (lab == keep).astype(np.uint8)
    full = np.zeros((H, W), np.float32)
    full[y0:y1, x0:x1] = fg
    return full

MASK = np.zeros((H, W), np.float32)
for r in REGIONS.values():
    m = grabcut(r['box'], r['cx'])
    # only the stretch that moves; what's above/below stays painted as it is
    m[:r['out'][0] - 2] = 0; m[r['out'][1]:] = 0
    r['mask'] = m
    MASK = np.maximum(MASK, m)

# Soft auger matte: the cut-out, slightly feathered, times the art's own alpha.
SOFT = cv2.GaussianBlur(MASK, (0, 0), 0.7) * A

def body_bottom():
    # Lower edge of the machine body behind the lower screw, from the columns just outside it.
    def edge(x):
        col = A[960:1120, x]
        idx = np.nonzero(col < 0.5)[0]
        return 960 + int(idx[0]) if len(idx) else 1042
    return (edge(528) + edge(722)) / 2.0

def textured_fill(rgb, hole):
    """Fill `hole` column by column from the panel visible above and below it in
    the same column, so the plate's vertical streaks and seams carry through."""
    out = cv2.inpaint(rgb, hole.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)
    for r in REGIONS.values():
        y0, y1, x0, x1 = r['box']
        ya, yb = r['out'][0] - 2, r['out'][1]
        for x in range(x0, x1):
            col_h = hole[ya:yb, x]
            if not col_h.any():
                continue
            rows = np.arange(ya, yb)
            known = ~col_h & (A[ya:yb, x] > 0.5)
            if known.sum() < 2:
                continue
            ky = rows[known]
            for ch in range(3):
                vals = rgb[ya:yb, x, ch][known].astype(np.float32)
                out[ya:yb, x, ch] = np.where(col_h, np.interp(rows, ky, vals), out[ya:yb, x, ch])
    # a little of the neighbouring columns' grain so it doesn't look combed
    noise = cv2.GaussianBlur(np.random.default_rng(3).normal(0, 6, rgb.shape[:2]).astype(np.float32), (0, 0), 1.2)
    out = np.clip(out.astype(np.float32) + np.where(hole, noise, 0)[..., None], 0, 255).astype(np.uint8)
    return out

def painted_out():
    """The machine with both screws painted out (what shows between the flights)."""
    base = S.copy()
    bands = np.zeros((H, W), bool)
    for r in REGIONS.values():
        bands[r['out'][0]:r['out'][1], r['box'][2]:r['box'][3]] = True
    hole = (cv2.dilate((MASK > 0).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & bands
    rgb = base[..., :3].astype(np.uint8).copy()
    filled = textured_fill(rgb, hole)
    base[..., :3] = np.where(hole[..., None], filled, base[..., :3])
    # Below the body there's nothing behind the lower screw.
    yb = int(round(body_bottom()))
    lo = REGIONS['lower']
    y0, y1, x0, x1 = lo['box']
    sub = hole[yb:lo['out'][1], x0:x1]
    base[yb:lo['out'][1], x0:x1, 3] = np.where(sub, 0, base[yb:lo['out'][1], x0:x1, 3])
    return base

BASE = painted_out()

def radius(r, y):
    t = (y - r['src'][0]) / max(1.0, r['src'][1] - r['src'][0])
    return r['r_top'] + (r['r_bot'] - r['r_top']) * np.clip(t, 0, 1)

def moved_region(r, d, feather=12.0):
    """Premultiplied colour and coverage of the screw moved down by d pixels."""
    y_out0, y_out1 = r['out']; s0, s1 = r['src']; P = r['pitch']
    x0, x1 = r['box'][2], r['box'][3]
    ys_out = np.arange(y_out0, y_out1, dtype=np.float32)
    xs = np.arange(x0, x1, dtype=np.float32)
    acc_c = np.zeros((len(ys_out), len(xs), 3), np.float32)
    acc_a = np.zeros((len(ys_out), len(xs)), np.float32)
    acc_w = np.zeros((len(ys_out), 1), np.float32)
    premul = RGB * SOFT[..., None]
    for k in range(-3, 4):
        ys = ys_out - d - k * P
        valid = (ys >= s0) & (ys <= s1)
        if not valid.any():
            continue
        # one pitch-long window of the painting is the tile; neighbouring
        # copies cross-fade over `feather` rows where they meet
        lo_w = r['win'][0] - feather / 2; hi_w = r['win'][1] + feather / 2
        valid = valid & (ys >= lo_w) & (ys <= hi_w)
        w = np.clip(np.minimum(ys - lo_w, hi_w - ys) / feather, 0.0, 1.0) * valid
        w = np.maximum(w, valid * 1e-4)
        scale = radius(r, ys) / radius(r, ys_out)
        mx = (r['cx'] + (xs[None, :] - r['cx']) * scale[:, None]).astype(np.float32)
        my = np.repeat(ys[:, None], len(xs), 1).astype(np.float32)
        c = cv2.remap(premul, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        a = cv2.remap(SOFT, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        acc_c += c * w[:, None, None]; acc_a += a * w[:, None]; acc_w += w[:, None]
    acc_w = np.maximum(acc_w, 1e-6)
    return acc_c / acc_w[..., None], acc_a / acc_w, (y_out0, x0)

def frame(i):
    out = BASE.copy()
    for r in REGIONS.values():
        d = r['pitch'] * i / N
        c, a, (y0, x0) = moved_region(r, d)
        h, w = a.shape
        if 'end' in r:
            # the screw's flights stop at a fixed height on the shaft; seen from
            # a little above, that end follows an ellipse and fades out
            yy, xx = np.mgrid[y0:y0 + h, x0:x0 + w].astype(np.float32)
            u = np.clip((xx - r['cx']) / r['r_bot'], -1, 1)
            cut = r['end'] + r['end_tilt'] * np.sqrt(1 - u * u)
            shaft = np.abs(xx - r['cx']) <= r['shaft_r']
            fade = np.clip((cut - yy) / 4.0, 0, 1)
            fade = np.where(shaft, 1.0, fade)
            c = c * fade[..., None]; a = a * fade
        dst = out[y0:y0 + h, x0:x0 + w]
        # the painting's soft shadow of the screw on the plate behind it
        sh = np.zeros_like(a); sh[6:, 8:] = a[:-6, :-8]
        sh = cv2.GaussianBlur(sh, (0, 0), 5.0) * r.get('shadow', 0.4)
        dst[..., :3] *= (1.0 - sh[..., None])
        da = dst[..., 3:] / 255.0
        # premultiplied "over"
        oa = a[..., None] + da * (1 - a[..., None])
        oc = (c + dst[..., :3] * da * (1 - a[..., None])) / np.maximum(oa, 1e-6)
        dst[..., :3] = np.where(oa > 1e-6, oc, dst[..., :3])
        dst[..., 3:] = oa * 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    frames = [frame(i) for i in range(N)]
    for i, f in enumerate(frames):
        f.save(os.path.join(OUT, f'f{i:02d}.png'))
    bgc = (30, 60, 40, 255)
    strip = Image.new('RGBA', (220 * 6, 760), bgc)
    for k, i in enumerate(range(0, 12, 2)):
        c = Image.new('RGBA', frames[i].size, bgc); c.alpha_composite(frames[i])
        strip.paste(c.crop((515, 380, 735, 1140)), (220 * k, 0))
    strip.convert('RGB').save(os.path.join(OUT, 'strip.png'))
    gif = []
    for f in frames:
        c = Image.new('RGBA', f.size, bgc); c.alpha_composite(f)
        gif.append(c.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS))
    gif[0].save(os.path.join(OUT, 'preview.gif'), save_all=True, append_images=gif[1:], duration=42, loop=0)
    zoom = []
    for f in frames:
        c = Image.new('RGBA', f.size, bgc); c.alpha_composite(f)
        zoom.append(c.crop((500, 400, 750, 1140)).convert('RGB'))
    zoom[0].save(os.path.join(OUT, 'preview_zoom.gif'), save_all=True, append_images=zoom[1:], duration=42, loop=0)
