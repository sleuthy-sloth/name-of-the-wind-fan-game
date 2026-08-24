#!/usr/bin/env python3
"""Inspect character and NPC sprite sheets for sprite wiring."""
from PIL import Image
import os, sys

TILE = 16

def inspect(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    cols = w // TILE
    rows = h // TILE
    print(f"\n{os.path.basename(path)}: {w}x{h} => {cols} cols x {rows} rows")

    # Sample first few non-transparent tiles per row
    for row in range(min(rows, 20)):
        non_transparent = []
        for col in range(cols):
            crop = img.crop((col*TILE, row*TILE, (col+1)*TILE, (row+1)*TILE))
            if any(p[3] > 0 for p in crop.getdata()):
                # Get avg color of opaque pixels
                opaque = [p for p in crop.getdata() if p[3] > 0]
                r = sum(p[0] for p in opaque) // len(opaque)
                g = sum(p[1] for p in opaque) // len(opaque)
                b = sum(p[2] for p in opaque) // len(opaque)
                non_transparent.append((col, f"#{r:02x}{g:02x}{b:02x}"))
        if non_transparent:
            print(f"  row {row:2d}: {len(non_transparent)} tiles, first: col={non_transparent[0][0]} {non_transparent[0][1]}, last: col={non_transparent[-1][0]}")

    # Print first 5 non-transparent tiles with details
    count = 0
    for row in range(rows):
        for col in range(cols):
            crop = img.crop((col*TILE, row*TILE, (col+1)*TILE, (row+1)*TILE))
            opaque = [p for p in crop.getdata() if p[3] > 0]
            if opaque:
                r = sum(p[0] for p in opaque) // len(opaque)
                g = sum(p[1] for p in opaque) // len(opaque)
                b = sum(p[2] for p in opaque) // len(opaque)
                print(f"  tile[{row},{col}] srcId={row*cols+col}: {len(opaque)} opaque px, avg=#{r:02x}{g:02x}{b:02x}")
                count += 1
                if count >= 15:
                    return

root = os.path.dirname(os.path.abspath(__file__))
base = os.path.join(root, "..", "..", "art", "sprites")
inspect(os.path.join(base, "zeldalike_character.png"))
inspect(os.path.join(base, "zeldalike_npc.png"))
