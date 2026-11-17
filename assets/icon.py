"""Draws the Script Doctor icon as PNG files, with no libraries beyond the standard one.

    python3 assets/icon.py            # writes assets/icon-64.png and assets/icon-512.png

64 px is the toolbar button (32 points on a Retina screen); 512 px is for the Creator Store
listing. Shapes are drawn from distance functions with one-pixel antialiasing, so every size
is drawn fresh instead of being scaled down.
"""

import math
import struct
import sys
import zlib
from pathlib import Path

BLUE = (0, 116, 204)  # the "Scan place" button colour (App.luau, PRIMARY)
RED = (214, 69, 69)  # the Security colour
WHITE = (255, 255, 255)
LINE = (120, 178, 228)  # light blue code lines


def rounded_box(px, py, cx, cy, hw, hh, r):
    qx, qy = abs(px - cx) - (hw - r), abs(py - cy) - (hh - r)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - r


def circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r


def shapes():
    """(distance function in 0..1 units, colour), painted in order."""
    return [
        # background
        (lambda x, y: rounded_box(x, y, 0.5, 0.5, 0.5, 0.5, 0.22), BLUE),
        # the page
        (lambda x, y: rounded_box(x, y, 0.44, 0.47, 0.235, 0.31, 0.06), WHITE),
        # code lines
        (lambda x, y: rounded_box(x, y, 0.40, 0.30, 0.12, 0.035, 0.035), LINE),
        (lambda x, y: rounded_box(x, y, 0.44, 0.42, 0.16, 0.035, 0.035), LINE),
        (lambda x, y: rounded_box(x, y, 0.37, 0.54, 0.09, 0.035, 0.035), LINE),
        # the badge: white ring, red circle, white cross
        (lambda x, y: circle(x, y, 0.70, 0.71, 0.225), WHITE),
        (lambda x, y: circle(x, y, 0.70, 0.71, 0.185), RED),
        (lambda x, y: rounded_box(x, y, 0.70, 0.71, 0.115, 0.04, 0.015), WHITE),
        (lambda x, y: rounded_box(x, y, 0.70, 0.71, 0.04, 0.115, 0.015), WHITE),
    ]


def render(size):
    pixel = 1.0 / size
    rows = []
    layers = shapes()
    for j in range(size):
        row = bytearray([0])  # PNG filter type 0 for this row
        y = (j + 0.5) * pixel
        for i in range(size):
            x = (i + 0.5) * pixel
            r = g = b = a = 0.0
            for distance, colour in layers:
                cover = min(max(0.5 - distance(x, y) / pixel, 0.0), 1.0)
                if cover <= 0.0:
                    continue
                # "over" with straight alpha
                out_a = cover + a * (1 - cover)
                r = (colour[0] * cover + r * a * (1 - cover)) / out_a
                g = (colour[1] * cover + g * a * (1 - cover)) / out_a
                b = (colour[2] * cover + b * a * (1 - cover)) / out_a
                a = out_a
            row += bytes((round(r), round(g), round(b), round(a * 255)))
        rows.append(bytes(row))
    return b"".join(rows)


def write_png(path, size, data):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(data, 9))
    path.write_bytes(png + chunk(b"IEND", b""))


def main():
    folder = Path(__file__).resolve().parent
    for size in (64, 512):
        path = folder / f"icon-{size}.png"
        write_png(path, size, render(size))
        print("written", path)


if __name__ == "__main__":
    sys.exit(main())
