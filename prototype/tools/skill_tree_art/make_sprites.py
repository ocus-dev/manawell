import cv2, numpy as np
src = cv2.imread("skill_board_source.png", cv2.IMREAD_UNCHANGED)[:, :, :3]

def cut(center, half, solid, fade, screen=None, name=""):
    x, y = int(round(center[0])), int(round(center[1]))
    crop = src[y - half:y + half, x - half:x + half].copy()
    if screen is not None:
        sx0, sy0, sx1, sy1 = screen
        roi = crop[sy0:sy1, sx0:sx1]
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        text = ((hsv[:, :, 2] > 95) & (hsv[:, :, 1] < 90)).astype(np.uint8) * 255
        text = cv2.dilate(text, np.ones((3, 3), np.uint8), iterations=2)
        m = np.zeros(crop.shape[:2], np.uint8)
        m[sy0:sy1, sx0:sx1] = text
        crop = cv2.inpaint(crop, m, 4, cv2.INPAINT_TELEA)
    # Erase trace stubs in the corners (pins never sit there).
    if name != "pad":
        hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
        warm = ((hsv[:, :, 2] > 120) & (hsv[:, :, 1] > 90)).astype(np.uint8)
        yy0, xx0 = np.mgrid[0:2 * half, 0:2 * half] - half
        corner = (np.abs(xx0) > half * 0.62) & (np.abs(yy0) > half * 0.62)
        m = (warm & corner).astype(np.uint8) * 255
        m = cv2.dilate(m, np.ones((3, 3), np.uint8))
        crop = cv2.inpaint(crop, m, 3, cv2.INPAINT_TELEA)
    # alpha: solid in the middle square (chips) / circle (pads), fading out.
    yy, xx = np.mgrid[0:2 * half, 0:2 * half].astype(np.float32) - half + 0.5
    if name == "pad":
        d = np.sqrt(xx * xx + yy * yy)
    else:
        d = np.maximum(np.abs(xx), np.abs(yy))
    alpha = np.clip(1.0 - (d - solid) / float(fade), 0.0, 1.0)
    rgba = np.dstack([crop, (alpha * 255).astype(np.uint8)])
    cv2.imwrite(f"skill_{name}.png", rgba)
    return rgba

# Keystone chip (BST): body ~60px plus pins.
cut((374, 128), 42, 37, 3, screen=(12, 12, 72, 72), name="keystone")
# Notable chip (RNF).
cut((289, 421), 34, 29, 3, screen=(10, 10, 58, 58), name="chip")
# Solder pad (mobility fork pad).
cut((365, 416), 17, 12.5, 2.5, name="pad")
