import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
from layout import *
plate = Image.open("skill_board_plate.png").convert("RGBA")
spr = {t: Image.open(f"skill_{t}.png").convert("RGBA") for t in ["keystone", "chip", "pad"]}
TEMPLATE = {"1": ("", "minor"), "2": ("1", "minor"), "3": ("2", "notable"), "f1": ("2", "minor"), "f2": ("f1", "notable"), "k": ("3", "keystone")}
CODES = {"armor": ("RNF", "ABL", "BST"), "weapons": ("OVR", "RAIL", "TWN"), "mobility": ("SRV", "FAR", "AFT"), "reactor": ("HOT", "RCY", "FSN"), "salvage": ("MAG", "RIG", "SCV"), "drill": ("DMD", "HAZ", "DCT")}
unl = {"armor_1", "armor_2", "armor_3", "armor_f1", "weapons_1", "weapons_2", "weapons_3", "weapons_k", "mobility_1", "salvage_1", "salvage_2", "salvage_f1", "salvage_f2", "reactor_1", "reactor_2"}
def state(n):
    b, k = n.split("_", 1); par = TEMPLATE[k][0]
    if n in unl: return "p"
    if not par or f"{b}_{par}" in unl: return "r"
    return "l"
S = 2
W, H = plate.size
base = plate.resize((W * S, H * S), Image.LANCZOS)
d = ImageDraw.Draw(base, "RGBA")
glow = Image.new("RGB", (W * S, H * S), (0, 0, 0)); g = ImageDraw.Draw(glow)
P = lambda p: (p[0] * S, p[1] * S)
routes = {}
for b, nodes in NODES.items():
    for k, pos in nodes.items():
        par = TEMPLATE[k][0]
        start = CORE_EXIT[b] if not par else nodes[par]
        routes[f"{b}_{k}"] = (start, pos)
for n, (a, c) in routes.items():
    st = state(n)
    col = {"p": (255, 194, 102), "r": (170, 100, 40), "l": (61, 43, 28)}[st]
    d.line([P(a), P(c)], fill=col, width=int(2.5 * S))
    if st == "p":
        g.line([P(a), P(c)], fill=(60, 28, 6), width=12 * S); g.line([P(a), P(c)], fill=(110, 52, 10), width=5 * S)
        g.ellipse([P((c[0]*0.6+a[0]*0.4-6, c[1]*0.6+a[1]*0.4-6)), P((c[0]*0.6+a[0]*0.4+6, c[1]*0.6+a[1]*0.4+6))], fill=(160, 90, 30))
    elif st == "r":
        g.line([P(a), P(c)], fill=(30, 14, 3), width=6 * S)
font = lambda n: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", n * S)
for b, nodes in NODES.items():
    for k, pos in nodes.items():
        n = f"{b}_{k}"; st = state(n); tier = TEMPLATE[k][1]
        im = spr["keystone" if tier == "keystone" else "chip" if tier == "notable" else "pad"]
        im = im.resize((im.width * S, im.height * S), Image.LANCZOS)
        m = {"p": 1.0, "r": 0.72, "l": 0.34}[st]
        arr = np.array(im).astype(float); arr[..., :3] *= m; im = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
        base.alpha_composite(im, (int(pos[0] * S - im.width / 2), int(pos[1] * S - im.height / 2)))
        if st == "p":
            r = {"keystone": 44, "notable": 38, "minor": 28}[tier]
            for i in range(4):
                rr = r * (1 - i * 0.2) * S; a = int(255 * 0.05 * (i + 1))
                g.ellipse([pos[0]*S-rr, pos[1]*S-rr, pos[0]*S+rr, pos[1]*S+rr], fill=(int(1.0*a), int(0.48*a), int(0.1*a)))
        if tier != "minor":
            code = {"3": 0, "f2": 1, "k": 2}[k]; code = CODES[b][code]
            col = {"p": (236, 230, 216), "r": (172, 163, 147), "l": (92, 86, 80)}[st]
            d.text(P(pos), code, font=font(15 if tier == "keystone" else 12), fill=col, anchor="mm")
cnt = {}
for b in NODES: cnt[b] = sum(1 for k in TEMPLATE if f"{b}_{k}" in unl)
COUNTPOS = {"armor": (292, 151), "weapons": (780, 151), "mobility": (178, 492), "reactor": (890, 492), "salvage": (291, 603), "drill": (784, 604)}
for b, p in COUNTPOS.items():
    d.text(P(p), f"{cnt[b]}/6", font=font(14), fill=(240, 176, 90) if cnt[b] else (185, 178, 163), anchor="ls")
glow = glow.filter(ImageFilter.GaussianBlur(2 * S))
out = ImageChops.add(base.convert("RGB"), glow)
out.resize((W, H), Image.LANCZOS).save("/mnt/user-data/outputs/skill_tree_art_preview.png")
