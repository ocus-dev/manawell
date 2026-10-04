# Continuous drilling loop for the drill sprite: the painted auger keeps turning
# with its head sunk in the ground, juddering, while rock chunks (with the odd
# mana crystal) and dust keep pouring out. Every effect wraps around the loop,
# so it never visibly stops or restarts.
import os, sys, math
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else 'prototype/assets/side-view/harvester.png'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'drill_frames'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.argv = [sys.argv[0], SRC, OUT]
import render_auger as ps   # the auger spin (the painting's own pixels), same folder

FRAMES = 48               # 2 s at 24 fps
SPIN_FRAMES = 12          # one revolution every 12 frames (same speed as before)
GROUND_Y = 1123.0         # feet line in harvester.png pixels
CX = 625.0
MAX_DEPTH = 46.0          # how far the drill head sinks into the ground
H, W = ps.H, ps.W
RNG = np.random.default_rng(11)

def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)

def depth_at(t):
    """Always sunk in, with a judder (whole cycles per loop so it wraps)."""
    return MAX_DEPTH + 1.5 * math.sin(t * 2 * math.pi * 14) + 0.8 * math.sin(t * 2 * math.pi * 5 + 1.0)

def biting(t):
    """0..1: how hard the bit is working (drives debris and dust)."""
    d = depth_at(t)
    return min(1.0, d / MAX_DEPTH) if 0.12 < t < 0.8 else 0.0

# ---------------- painted sprites for debris ----------------

OUTLINE = (24, 18, 16)

def make_rock(size, rng, kind):
    """A small chunk painted like the drill art: faceted, lit from the upper
    left, dark ink outline, rust specks; 'crystal' chunks glow mana teal."""
    ss = 3; S = int(size * ss)
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    n = int(rng.integers(6, 10))
    ang = np.sort(rng.uniform(0, 2 * np.pi, n))
    rad = rng.uniform(0.38, 0.48, n) * S
    pts = [(S / 2 + r * math.cos(a), S / 2 + r * math.sin(a) * rng.uniform(0.85, 1.0)) for a, r in zip(ang, rad)]
    if kind == 'crystal':
        base = np.array([38, 120, 128]); lit = np.array([150, 240, 228]); dark = np.array([16, 52, 60])
    elif kind == 'rust':
        base = np.array([112, 70, 44]); lit = np.array([196, 132, 78]); dark = np.array([46, 30, 24])
    else:
        base = np.array([70, 60, 54]); lit = np.array([124, 108, 94]); dark = np.array([26, 22, 22])
    # facets: fan from an off-centre point, each facet shaded by its facing
    cxp = S / 2 + rng.uniform(-0.12, 0.12) * S; cyp = S / 2 + rng.uniform(-0.12, 0.12) * S
    d = ImageDraw.Draw(img)
    light = np.array([-0.62, -0.78])
    for i in range(n):
        p0, p1 = pts[i], pts[(i + 1) % n]
        mid = np.array([(p0[0] + p1[0]) / 2 - cxp, (p0[1] + p1[1]) / 2 - cyp])
        nrm = mid / (np.linalg.norm(mid) + 1e-6)
        b = 0.5 + 0.5 * float(nrm @ light)
        col = dark + (lit - dark) * (0.2 + 0.7 * b) ** 1.2
        d.polygon([(cxp, cyp), p0, p1], fill=tuple(int(c) for c in col) + (255,))
    arr = np.array(img).astype(np.float32)
    a = arr[..., 3] > 0
    # grain + rust specks (or crystal sparkle)
    grain = cv2.GaussianBlur(rng.normal(0, 1, (S, S)).astype(np.float32), (0, 0), 1.6)
    arr[..., :3] += grain[..., None] * 14
    spk = cv2.GaussianBlur(rng.random((S, S)).astype(np.float32), (0, 0), 2.0)
    spk = np.clip((spk - 0.62) * 6, 0, 1)
    tint = np.array([150, 80, 40]) if kind != 'crystal' else np.array([210, 255, 245])
    arr[..., :3] = arr[..., :3] * (1 - spk[..., None] * 0.55) + tint * spk[..., None] * 0.55
    # bright rim on the lit edges
    m = a.astype(np.uint8)
    edge = (m - cv2.erode(m, np.ones((5, 5), np.uint8))) > 0
    gx = cv2.Sobel(m.astype(np.float32), cv2.CV_32F, 1, 0); gy = cv2.Sobel(m.astype(np.float32), cv2.CV_32F, 0, 1)
    lit_edge = edge & ((gx * -light[0] + gy * -light[1]) < 0)
    arr[lit_edge, :3] = arr[lit_edge, :3] * 0.4 + lit * 0.6 + 30
    # ink outline
    outl = (cv2.dilate(m, np.ones((7, 7), np.uint8)) > 0) & ~a
    arr[outl] = list(OUTLINE) + [255]
    arr[..., 3] = np.where(a | outl, 255, 0)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')
    return img.resize((int(size), int(size)), Image.LANCZOS)

def make_puff(size, rng):
    """A soft dust/steam puff with a painted, lumpy edge."""
    S = int(size)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    acc = np.zeros((S, S), np.float32)
    for _ in range(7):
        cx = S / 2 + rng.uniform(-0.18, 0.18) * S; cy = S / 2 + rng.uniform(-0.12, 0.18) * S
        r = rng.uniform(0.18, 0.3) * S
        acc = np.maximum(acc, np.clip(1 - np.hypot(xx - cx, yy - cy) / r, 0, 1))
    noise = cv2.GaussianBlur(rng.random((S, S)).astype(np.float32), (0, 0), S / 28)
    noise = (noise - noise.min()) / (noise.max() - noise.min() + 1e-6)
    alpha = np.clip(acc * 1.6 - 0.15 + (noise - 0.5) * 0.5, 0, 1) ** 1.2
    shade = np.clip(1.0 - (yy - S * 0.3) / S * 0.9 + (noise - 0.5) * 0.3, 0.45, 1.1)
    base = np.array([186, 160, 128], np.float32)
    rgb = base[None, None, :] * shade[..., None]
    rgb[..., 0] += 10  # warm, dusty
    return np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)

ROCK_SPRITES = [make_rock(int(RNG.integers(34, 70)), RNG, RNG.choice(['stone', 'stone', 'stone', 'rust', 'crystal'], p=[0.35, 0.25, 0.15, 0.13, 0.12])) for _ in range(40)]
PUFFS = [make_puff(128, RNG) for _ in range(8)]

# ---------------- particles (one cycle, deterministic) ----------------

GRAV = 1500.0   # px/s^2 in sprite pixels
DT = 2.0 / FRAMES

rocks = []
for k in range(34):
    t0 = (k + float(RNG.uniform(0, 0.8))) / 34.0
    side = -1 if k % 2 == 0 else 1
    rocks.append(dict(t0=t0, x=CX + side * RNG.uniform(10, 40), y=GROUND_Y - 6,
                      vx=side * RNG.uniform(90, 420), vy=-RNG.uniform(260, 640),
                      rot0=RNG.uniform(0, 360), spin=RNG.uniform(-540, 540),
                      spr=ROCK_SPRITES[k % len(ROCK_SPRITES)]))
puffs = []
for k in range(40):
    t0 = (k + float(RNG.uniform(0, 0.8))) / 40.0
    side = RNG.choice([-1, 1])
    puffs.append(dict(t0=t0, life=float(RNG.uniform(0.3, 0.5)), x=CX + side * RNG.uniform(5, 60), y=GROUND_Y - 8,
                      vx=side * RNG.uniform(60, 300), vy=-RNG.uniform(50, 170), r0=RNG.uniform(40, 60), r1=RNG.uniform(160, 290),
                      a0=RNG.uniform(0.6, 0.85), puff=PUFFS[k % len(PUFFS)]))

def rock_state(r, t):
    """Position/rotation/alpha of a rock at cycle time t (seconds-based)."""
    age = (t - r['t0']) % 1.0         # wraps around the loop
    s = age * 2.0                      # seconds since launch (loop = 2 s)
    x = r['x'] + r['vx'] * s
    y = r['y'] + r['vy'] * s + 0.5 * GRAV * s * s
    size = r['spr'].width
    rest = GROUND_Y - size * 0.45
    rot = r['rot0'] + r['spin'] * s
    if y >= rest and s > 0.05:
        # landed: find landing time, slide a little, then rest
        a = 0.5 * GRAV; b = r['vy']; c = r['y'] - rest
        tl = (-b + math.sqrt(max(b * b - 4 * a * c, 0))) / (2 * a)
        x = r['x'] + r['vx'] * tl + r['vx'] * 0.12 * min(s - tl, 0.25)
        y = rest
        rot = r['rot0'] + r['spin'] * tl
    # settled chunks fade out after a moment so they don't pile up
    alpha = 1.0 - smooth((age - 0.5) / 0.25)
    return x, y, rot, alpha

# ---------------- frame composition ----------------

LOWER = ps.REGIONS['lower']
UPPER = ps.REGIONS['upper']

def base_without_tip():
    """The painted-out machine with the shaft stub and bit removed (they move)."""
    b = ps.BASE.copy()
    b[1044:, 560:690, 3] = 0
    return b

BASE2 = base_without_tip()
TIP = ps.S[1048:1133, 560:690].copy()   # painted shaft stub + bit
TIP_Y0, TIP_X0 = 1048, 560

def over(dst, src_rgb, src_a, y0, x0, clip=None):
    """Composite straight-alpha src onto dst (float RGBA, 0..255) at (y0, x0)."""
    h, w = src_a.shape
    ya, yb = max(0, y0), min(dst.shape[0], y0 + h)
    xa, xb = max(0, x0), min(dst.shape[1], x0 + w)
    if ya >= yb or xa >= xb:
        return
    s_rgb = src_rgb[ya - y0:yb - y0, xa - x0:xb - x0]
    s_a = src_a[ya - y0:yb - y0, xa - x0:xb - x0].copy()
    if clip is not None:
        s_a *= clip[ya:yb, xa:xb]
    d = dst[ya:yb, xa:xb]
    da = d[..., 3:] / 255.0; sa = s_a[..., None]
    oa = sa + da * (1 - sa)
    oc = (s_rgb * sa + d[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    d[..., :3] = np.where(oa > 1e-6, oc, d[..., :3]); d[..., 3:] = oa * 255

def frame(i):
    t = i / FRAMES
    spin = (i % SPIN_FRAMES) / SPIN_FRAMES
    D = depth_at(t)
    out = BASE2.copy()
    yy = np.arange(H, dtype=np.float32)[:, None]
    ground_clip = np.clip(GROUND_Y + 0.5 - yy, 0, 1) * np.ones((1, W), np.float32)
    # upper screw: spin plus the plunge (it's one long screw)
    c, a, (y0, x0) = ps.moved_region(UPPER, UPPER['pitch'] * spin + D)
    sh = np.zeros_like(a); sh[6:, 8:] = a[:-6, :-8]
    out[y0:y0 + a.shape[0], x0:x0 + a.shape[1], :3] *= (1 - cv2.GaussianBlur(sh, (0, 0), 5.0)[..., None] * UPPER['shadow'])
    over(out, c / np.maximum(a[..., None], 1e-6), a, y0, x0)
    # lower screw: spun, then the whole head moves down by D
    lo = dict(LOWER); lo['out'] = (LOWER['out'][0] - int(MAX_DEPTH) - 4, LOWER['out'][1])
    c, a, (y0, x0) = ps.moved_region(lo, LOWER['pitch'] * spin)
    hh, ww = a.shape
    yg, xg = np.mgrid[y0:y0 + hh, x0:x0 + ww].astype(np.float32)
    u = np.clip((xg - CX) / LOWER['r_bot'], -1, 1)
    cut = LOWER['end'] + LOWER['end_tilt'] * np.sqrt(1 - u * u)
    fade = np.where(np.abs(xg - CX) <= LOWER['shaft_r'], 1.0, np.clip((cut - yg) / 4.0, 0, 1))
    a = a * fade
    Di = int(round(D)); fy = D - Di
    top_clip = np.zeros((H, W), np.float32); top_clip[LOWER['out'][0]:, :] = 1
    clip = top_clip * ground_clip
    sh = np.zeros_like(a); sh[6:, 8:] = a[:-6, :-8]
    shy0 = y0 + Di
    band = out[max(shy0, LOWER['out'][0]):min(shy0 + hh, 1044), x0:x0 + ww]
    if band.size:
        s2 = cv2.GaussianBlur(sh, (0, 0), 5.0)[max(shy0, LOWER['out'][0]) - shy0:min(shy0 + hh, 1044) - shy0]
        band[..., :3] *= (1 - s2[..., None] * LOWER['shadow'])
    rgb = c / np.maximum(a[..., None], 1e-6)
    # stub + bit below the flights, same offset
    over(out, rgb, a, y0 + Di, x0, clip)
    over(out, TIP[..., :3], TIP[..., 3] / 255.0, TIP_Y0 + Di, TIP_X0, clip)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')
    # churned-up ground around the bit (a dark crater lip with rubble on it)
    bite = min(1.0, D / MAX_DEPTH)
    if bite > 0.02:
        lip = Image.new('RGBA', (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lip)
        wlip = 60 + 110 * bite; hlip = 8 + 14 * bite
        dl.ellipse((CX - wlip, GROUND_Y - hlip, CX + wlip, GROUND_Y + hlip * 0.25), fill=(52, 40, 34, int(235 * min(1, bite * 2))))
        dl.ellipse((CX - wlip * 0.8, GROUND_Y - hlip * 0.85, CX + wlip * 0.8, GROUND_Y - hlip * 0.1), fill=(88, 70, 56, int(220 * min(1, bite * 2))))
        lip = lip.filter(ImageFilter.GaussianBlur(1.2))
        img.alpha_composite(lip)
        # rubble resting on the lip
        rr = np.random.default_rng(5)
        for k in range(int(4 + 8 * bite)):
            spr = ROCK_SPRITES[(k * 7) % len(ROCK_SPRITES)]
            s = spr.resize((max(6, int(spr.width * 0.6)), max(6, int(spr.height * 0.6))), Image.LANCZOS)
            px = CX + rr.uniform(-1, 1) * wlip * 0.85 - s.width / 2
            py = GROUND_Y - hlip * rr.uniform(0.3, 0.9) - s.height / 2
            s = s.copy(); s.putalpha(Image.fromarray((np.array(s)[..., 3] * min(1, bite * 2)).astype(np.uint8)))
            img.alpha_composite(s, (int(px), int(py)))
    # flying / settled rock chunks
    for r in rocks:
        st = rock_state(r, t)
        if st is None:
            continue
        x, y, rot, alpha = st
        if alpha <= 0.01:
            continue
        s = r['spr'].rotate(rot, resample=Image.BICUBIC, expand=True)
        if alpha < 1:
            arr = np.array(s); arr[..., 3] = (arr[..., 3] * alpha).astype(np.uint8); s = Image.fromarray(arr)
        img.alpha_composite(s, (int(x - s.width / 2), int(y - s.height / 2)))
    # dust billowing from the hole (drawn last, partly over the machine's foot)
    for p in puffs:
        age = (t - p['t0']) % 1.0
        if age > p['life']:
            continue
        k = age / p['life']
        s_sec = age * 2.0
        rad = p['r0'] + (p['r1'] - p['r0']) * (1 - (1 - k) ** 2)
        x = p['x'] + p['vx'] * s_sec; y = p['y'] + p['vy'] * s_sec - rad * 0.35
        al = p['a0'] * (1 - k) ** 1.3 * min(1.0, k * 6)
        sz = int(rad * 2)
        pf = cv2.resize(p['puff'], (sz, sz), interpolation=cv2.INTER_LINEAR).astype(np.float32)
        pf[..., 3] *= al
        img.alpha_composite(Image.fromarray(pf.astype(np.uint8), 'RGBA'), (int(x - sz / 2), int(y - sz / 2)))
    # nothing pokes out below the ground line (dust, rubble)
    arr = np.array(img); arr[int(GROUND_Y) + 3:, :, 3] = 0
    return Image.fromarray(arr, 'RGBA')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    frames = [frame(i) for i in range(FRAMES)]
    for i, f in enumerate(frames):
        f.save(os.path.join(OUT, f'd{i:02d}.png'))
    bgc = (30, 60, 40, 255)
    gif = []
    for f in frames:
        c = Image.new('RGBA', f.size, bgc); c.alpha_composite(f)
        gif.append(c.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS))
    gif[0].save(os.path.join(OUT, 'drill_preview.gif'), save_all=True, append_images=gif[1:], duration=42, loop=0)
    zoom = []
    for f in frames:
        c = Image.new('RGBA', f.size, bgc); c.alpha_composite(f)
        zoom.append(c.crop((330, 820, 930, 1133)).convert('RGB'))
    zoom[0].save(os.path.join(OUT, 'drill_zoom.gif'), save_all=True, append_images=zoom[1:], duration=42, loop=0)
    sheet = Image.new('RGB', (600 * 4, 313 * 3))
    for k, i in enumerate([0, 6, 10, 14, 18, 24, 30, 36, 40, 42, 44, 47]):
        sheet.paste(zoom[i], ((k % 4) * 600, (k // 4) * 313))
    sheet.save(os.path.join(OUT, 'sheet.png'))
