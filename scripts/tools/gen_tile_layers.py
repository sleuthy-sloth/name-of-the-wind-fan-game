#!/usr/bin/env python3
"""Generate gridTiles JSON arrays for LDtk Ground and Props layers."""
import json, sys

W, H = 20, 15  # grid dimensions
TS = 16         # tile size

def tile(x, y, src_id):
    return {"px": [x*TS, y*TS], "srcId": src_id, "t": 1, "f": 0}

def gen_caravan_route():
    ground = []
    for y in range(H):
        for x in range(W):
            if y == 7:
                ground.append(tile(x, y, 1))  # dirt path
            else:
                ground.append(tile(x, y, 0))  # grass
    props = []
    # Trees along top and bottom borders
    for x in range(W):
        props.append(tile(x, 0, 90))   # tree
        props.append(tile(x, 14, 90))  # tree
    # Rocks near collision walls (col 8, rows 3-4 and 9-10)
    for y in [3, 4, 9, 10]:
        props.append(tile(8, y, 30))  # rock
    # Trees on left/right borders (skip path row)
    for y in range(1, 14):
        if y != 7:
            props.append(tile(0, y, 90))
            props.append(tile(19, y, 90))
    return ground, props

def gen_forest_campsite():
    ground = []
    for y in range(H):
        for x in range(W):
            # Dirt clearing in center (rows 5-9, cols 6-13)
            if 5 <= y <= 9 and 6 <= x <= 13:
                ground.append(tile(x, y, 1))  # dirt
            else:
                ground.append(tile(x, y, 0))  # grass
    props = []
    # Dense trees around borders
    for x in range(W):
        props.append(tile(x, 0, 90))
        props.append(tile(x, 14, 90))
    for y in range(1, 14):
        props.append(tile(0, y, 90))
        props.append(tile(19, y, 90))
    # A few trees inside near clearing edge
    props.append(tile(5, 5, 90))
    props.append(tile(14, 5, 90))
    props.append(tile(5, 9, 90))
    props.append(tile(14, 9, 90))
    # Rocks scattered
    props.append(tile(7, 6, 30))
    props.append(tile(12, 8, 30))
    return ground, props

def main():
    if len(sys.argv) < 2:
        print("Usage: gen_tile_layers.py <caravan_route|forest_campsite>")
        return 1
    name = sys.argv[1]
    if name == "caravan_route":
        ground, props = gen_caravan_route()
    elif name == "forest_campsite":
        ground, props = gen_forest_campsite()
    else:
        print(f"Unknown map: {name}")
        return 1
    print("--- GROUND_TILES ---")
    print(json.dumps(ground))
    print("--- PROPS_TILES ---")
    print(json.dumps(props))
    return 0

if __name__ == "__main__":
    sys.exit(main())
