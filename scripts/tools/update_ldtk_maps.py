#!/usr/bin/env python3
"""Update LDtk maps with tileset definitions and Ground/Props tile layers."""
import json, sys
from pathlib import Path

W, H, TS = 20, 15, 16
COLS = 40  # tileset columns

def tile(x, y, src_id):
    return {"px": [x*TS, y*TS], "srcId": src_id, "t": 1, "f": 0}

def gen_caravan_route():
    ground = []
    for y in range(H):
        for x in range(W):
            ground.append(tile(x, y, 1 if y == 7 else 0))
    props = []
    for x in range(W):
        props.append(tile(x, 0, 90))
        props.append(tile(x, 14, 90))
    for y in range(1, 14):
        if y != 7:
            props.append(tile(0, y, 90))
            props.append(tile(19, y, 90))
    for y in [3, 4, 9, 10]:
        props.append(tile(8, y, 30))
    return ground, props

def gen_forest_campsite():
    ground = []
    for y in range(H):
        for x in range(W):
            if 5 <= y <= 9 and 6 <= x <= 13:
                ground.append(tile(x, y, 1))
            else:
                ground.append(tile(x, y, 0))
    props = []
    for x in range(W):
        props.append(tile(x, 0, 90))
        props.append(tile(x, 14, 90))
    for y in range(1, 14):
        props.append(tile(0, y, 90))
        props.append(tile(19, y, 90))
    props.append(tile(5, 5, 90))
    props.append(tile(14, 5, 90))
    props.append(tile(5, 9, 90))
    props.append(tile(14, 9, 90))
    props.append(tile(7, 6, 30))
    props.append(tile(12, 8, 30))
    return ground, props

TILESET_DEF = {
    "uid": 20,
    "identifier": "zeldalike_overworld",
    "relPath": "../art/tilesets/zeldalike_overworld.png",
    "pxWid": 640,
    "pxHei": 576,
    "tileGridSize": 16,
    "spacing": 0,
    "padding": 0,
    "tags": [],
    "tagsSourceEnumUid": None,
    "enumTags": [],
    "customData": []
}

GROUND_LAYER_DEF = {"uid": 21, "identifier": "Ground", "type": "Tiles", "gridSize": 16, "tilesetDefUid": 20}
PROPS_LAYER_DEF = {"uid": 22, "identifier": "Props", "type": "Tiles", "gridSize": 16, "tilesetDefUid": 20}

def make_tile_layer_instance(uid, name, grid_tiles):
    return {"layerDefUid": uid, "identifier": name, "__type": "Tiles",
            "__cWid": W, "__cHei": H, "__gridSize": TS, "gridTiles": grid_tiles,
            "__tilesetRelPath": "../art/tilesets/zeldalike_overworld.png"}

def main():
    root = Path(__file__).resolve().parents[2]
    maps = {"caravan_route": gen_caravan_route, "forest_campsite": gen_forest_campsite}
    for name, genfn in maps.items():
        fpath = root / "maps" / f"{name}.ldtk"
        data = json.loads(fpath.read_text())
        data["nextUid"] = 52
        data["defs"]["tilesets"] = [TILESET_DEF]
        # Insert Ground and Props before Collision in layerDefs
        existing = data["defs"]["layerDefs"]
        data["defs"]["layerDefs"] = [GROUND_LAYER_DEF, PROPS_LAYER_DEF] + existing
        ground, props = genfn()
        level = data["levels"][0]
        level["layerInstances"] = [make_tile_layer_instance(21, "Ground", ground),
                                    make_tile_layer_instance(22, "Props", props)] + level["layerInstances"]
        fpath.write_text(json.dumps(data, indent=2))
        print(f"Updated {fpath.name}: {len(ground)} ground tiles, {len(props)} props tiles")
    return 0

if __name__ == "__main__":
    sys.exit(main())
