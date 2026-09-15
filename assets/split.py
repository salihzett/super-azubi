"""Sprite-Sheet (Magenta-Hintergrund) -> einzelne Frames, gleiche Höhe, als ein PNG-Streifen.
usage: split.py in.png out.png target_h expected_frames
"""
import sys
from PIL import Image
import numpy as np

src, dst, H, N = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src).convert('RGBA')
a = np.array(im).astype(int)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
# Magenta keyen: rot+blau hoch, grün niedrig (mit Toleranz für Kompressions-Ränder)
bg = (r > 150) & (b > 150) & (g < 110) & (abs(r - b) < 90)
a[..., 3] = np.where(bg, 0, 255)
# Spalten mit Inhalt -> zusammenhängende Bereiche = Frames
cols = (~bg).any(axis=0)
frames, start = [], None
for x, c in enumerate(cols):
    if c and start is None: start = x
    if not c and start is not None:
        if x - start > 8: frames.append((start, x))
        start = None
if start is not None: frames.append((start, len(cols)))
# Mini-Fragmente (Kompressionsreste) in Nachbarn mergen
merged = []
for f in frames:
    if merged and f[0] - merged[-1][1] < 6: merged[-1] = (merged[-1][0], f[1])
    else: merged.append(f)
frames = merged
# Überlappende Frames (Beine berühren sich): breitesten Bereich gleichmäßig teilen
while len(frames) < N:
    i = max(range(len(frames)), key=lambda k: frames[k][1] - frames[k][0])
    x0, x1 = frames[i]; k = N - len(frames) + 1
    frames[i:i+1] = [(x0 + (x1 - x0) * j // k, x0 + (x1 - x0) * (j + 1) // k) for j in range(k)]
print('frames:', len(frames), frames)
assert len(frames) == N, f'expected {N} frames'
rows = (~bg).any(axis=1)
y0, y1 = np.argmax(rows), len(rows) - np.argmax(rows[::-1])
out_im = Image.fromarray(a.astype('uint8'))
crops = [out_im.crop((x0, y0, x1, y1)) for x0, x1 in frames]
# einheitliche Frame-Breite = breitester Frame, Fuß-Baseline unten ausgerichtet
scale = H / (y1 - y0)
W = max(int(round(c.width * scale)) for c in crops)
strip = Image.new('RGBA', (W * N, H), (0, 0, 0, 0))
for i, c in enumerate(crops):
    c2 = c.resize((max(1, int(round(c.width * scale))), H), Image.LANCZOS)
    strip.paste(c2, (i * W + (W - c2.width) // 2, 0), c2)
strip.save(dst)
print('saved', dst, 'frame', W, 'x', H)
