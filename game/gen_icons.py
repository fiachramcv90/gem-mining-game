#!/usr/bin/env python3
"""Generate the PWA icons for the Gem Miner game (spec §11: PWA on).

Pure-stdlib PNG writer (zlib only) so it runs anywhere with no Pillow/ImageMagick.
Draws a dark rounded square with a gold gem/diamond (the prize gem). Placeholder
until the real art pass (spec §7) — regenerate by running `python3 gen_icons.py`.

Outputs icons/icon-144.png, icon-180.png, icon-512.png (the sizes Godot's PWA
export references) — see export_presets.cfg progressive_web_app/icon_*.
"""
import struct
import zlib

BG = (0x2a, 0x2c, 0x36)      # dark slate
GEM = (0xff, 0xcd, 0x46)     # prize gold
GEM_HI = (0xff, 0xe4, 0x96)  # highlight
GEM_LO = (0xc7, 0x92, 0x2c)  # shadow


def rounded(x, y, w, h, r):
    """True if (x,y) is inside a rounded-rect of size w×h with corner radius r."""
    cx = min(max(x, r), w - r)
    cy = min(max(y, r), h - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def in_diamond(x, y, cx, cy, half):
    """True inside an axis-aligned diamond (|dx|+|dy| <= half)."""
    return abs(x - cx) + abs(y - cy) <= half


def make(size):
    r = int(size * 0.18)
    cx = size / 2.0
    cy = size * 0.52
    half = size * 0.30
    px = bytearray()
    for y in range(size):
        px.append(0)  # PNG filter byte (none) at the start of each row
        for x in range(size):
            col = None
            if in_diamond(x, y, cx, cy, half):
                # simple facet shading: top-left highlight, bottom-right shadow
                if (x - cx) + (y - cy) < -half * 0.25:
                    col = GEM_HI
                elif (x - cx) + (y - cy) > half * 0.25:
                    col = GEM_LO
                else:
                    col = GEM
            elif rounded(x, y, size, size, r):
                col = BG
            else:
                # transparent outside the rounded square
                px.extend((0, 0, 0, 0))
                continue
            px.extend((col[0], col[1], col[2], 255))
    return bytes(px)


def write_png(path, size):
    raw = make(size)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    idat = zlib.compress(raw, 9)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))
    print(f"wrote {path} ({size}x{size})")


if __name__ == "__main__":
    import os

    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "icons")
    os.makedirs(out, exist_ok=True)
    for s in (144, 180, 512):
        write_png(os.path.join(out, f"icon-{s}.png"), s)
