import cv2, numpy as np
from layout import *
src = cv2.imread("skill_board_source.png", cv2.IMREAD_UNCHANGED)
bgr = src[:, :, :3].copy()
H, W = bgr.shape[:2]
mask = np.zeros((H, W), np.uint8)
for name, (x, y) in CHIPS.items():
    h = 37 if name in KEYSTONES else 31
    cv2.rectangle(mask, (int(x - h), int(y - h)), (int(x + h), int(y + h)), 255, -1)
for (x, y) in PADS:
    cv2.circle(mask, (int(x), int(y)), 19, 255, -1)
for (x0, y0, x1, y1) in COUNTS.values():
    cv2.rectangle(mask, (x0, y0), (x1, y1), 255, -1)
b, g, r = [bgr[:, :, i].astype(int) for i in range(3)]
keep = np.zeros((H, W), bool)
keep[332:497, 468:628] = True
keep[240:270, 490:606] = True
keep[548:584, 490:606] = True
keep[:, :52] = True; keep[:, 1082:] = True; keep[:48, :] = True; keep[728:, :] = True
hot = ((r > 150) & (g > 60) & (r - b > 90) & (r > g)) & ~keep
hot = cv2.dilate(hot.astype(np.uint8) * 255, np.ones((5, 5), np.uint8))
# Orange glow around lit parts: warm tint near anything hot or masked.
near = cv2.dilate(cv2.bitwise_or(hot, mask), np.ones((15, 15), np.uint8)) > 0
glow = near & (r - b > 38) & (r > 70) & ~keep
mask = cv2.bitwise_or(mask, hot)
mask[glow] = 255
mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
mask[keep] = 0
cv2.imwrite("debug_mask.png", mask)
base = cv2.inpaint(bgr, mask, 12, cv2.INPAINT_TELEA).astype(np.float32)
# Grain: fine noise like the board's grime instead of a smooth smear.
rng = np.random.default_rng(5)
noise = rng.normal(0, 1, (H, W)).astype(np.float32)
grain = (cv2.GaussianBlur(noise, (0, 0), 0.8) * 9.0 + cv2.GaussianBlur(noise, (0, 0), 3.0) * 10.0)[..., None]
soft = cv2.GaussianBlur((mask > 0).astype(np.float32), (0, 0), 2)[..., None]
# Pull the fill a little toward the board's average dark tone to kill smears.
blurred = cv2.GaussianBlur(base, (0, 0), 6)
fill = blurred * 0.75 + base * 0.25 + grain
out = bgr.astype(np.float32) * (1 - soft) + fill * soft
cv2.imwrite("skill_board_plate.png", np.clip(out, 0, 255).astype(np.uint8))
