"""Turn the owner's Studio captures into the store screenshots and the icon.

Usage: python3 -I tools/shots.py <captures-dir> <repo-dir>

For each capture: crop to 16:9 centred, scale to 1280x720, save as JPEG at the
highest quality that keeps the file at or under 250 KiB. Also writes
branding/icon-512.png, a square crop of the cover centred on the gremlins.
"""
import io
import os
import sys

from PIL import Image

NAMES = ["1-cover", "2-buy", "3-threat", "4-progress"]
SIZE = (1280, 720)
MAX_BYTES = 250 * 1024
# Square on the cover capture (1327x703), centred on the gremlin pedestals.
ICON_CENTRE = (652, 372)
ICON_SIDE = 410
# Per-capture left edge for the 16:9 crop (default: centred). The cover keeps the
# game logo and order rewards on the right whole; it gives up "STALL 10/10" on the left.
CROP_LEFT = {"1-cover": 62}


def crop_16x9(img, left=None):
    w, h = img.size
    if w * 9 > h * 16:  # too wide
        nw = round(h * 16 / 9)
        left = (w - nw) // 2 if left is None else max(0, min(w - nw, left))
        return img.crop((left, 0, left + nw, h))
    nh = round(w * 9 / 16)
    top = (h - nh) // 2
    return img.crop((0, top, w, top + nh))


def encode(img):
    for q in range(95, 39, -1):
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=q, optimize=True, progressive=True, subsampling=0 if q >= 90 else 2)
        if buf.tell() <= MAX_BYTES:
            return buf.getvalue(), q
    raise SystemExit("cannot reach 250 KiB")


def main(src, repo):
    out = os.path.join(repo, "screenshots")
    os.makedirs(out, exist_ok=True)
    for name in NAMES:
        path = os.path.join(src, name + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGB")
        small = crop_16x9(img, CROP_LEFT.get(name)).resize(SIZE, Image.LANCZOS)
        data, q = encode(small)
        with open(os.path.join(out, name + ".jpg"), "wb") as f:
            f.write(data)
        print(f"{name}.jpg {img.size} -> {SIZE} q={q} {len(data)} bytes")

    cover = Image.open(os.path.join(src, "1-cover.png")).convert("RGB")
    cx, cy = ICON_CENTRE
    half = ICON_SIDE // 2
    top = max(0, min(cover.height - ICON_SIDE, cy - half))
    left = max(0, min(cover.width - ICON_SIDE, cx - half))
    icon = cover.crop((left, top, left + ICON_SIDE, top + ICON_SIDE)).resize((512, 512), Image.LANCZOS)
    os.makedirs(os.path.join(repo, "branding"), exist_ok=True)
    icon.save(os.path.join(repo, "branding", "icon-512.png"), optimize=True)
    print("branding/icon-512.png", (left, top, ICON_SIDE))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
