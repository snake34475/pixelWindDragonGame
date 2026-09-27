#!/usr/bin/env python3
"""解析 unity-app 分支 SampleScene 的 Tilemap 地形与道具，产出 Godot 可用的 town_map.json。

坐标约定
--------
* Unity y 轴向上、Godot y 轴向下      -> godot_y = -unity_y
* Unity 1 单位 = 1 个 Grid 格 = 64 px -> Godot px = unity_unit * 64
* Tilemap 格 (ux, uy) 的中心在 Unity 世界 (ux+0.5, uy+0.5)；
  Godot TileMapLayer 格 (gx, gy) 的中心在 ((gx+0.5)*64, (gy+0.5)*64)
  => gx = ux, gy = -uy - 1
* Unity 图集 rect 的 y 自下而上 -> godot_atlas_y = atlas_h - rect.y - rect.h

用法:
    python3 tools/convert_unity_scene.py --probe   # 只打印诊断
    python3 tools/convert_unity_scene.py           # 写 resources/world/town_map.json
"""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNITY_BRANCH = "unity-app"
SCENE_PATH = "Assets/Scenes/SampleScene.unity"
TILE_ATLAS_PATH = "Assets/img/map/地面素材/初始32格子素材.png"
UNITY_PX_PER_UNIT = 64.0          # 1 格 = 1 单位 = 64 px（瓦片切片 64x64 + PPU 64 自洽）
PACKED_COLUMNS = 8

OUT_JSON = os.path.join(REPO, "resources/world/town_map.json")

# 计划中明确排除、不作为道具导入的场景对象
EXCLUDED_PROPS = {"佟湘玉", "传送圈", "Player", "player"}


def git_show(path: str) -> str:
    proc = subprocess.run(["git", "show", f"{UNITY_BRANCH}:{path}"],
                          cwd=REPO, capture_output=True)
    if proc.returncode != 0:
        sys.exit(f"git show 失败: {path}\n{proc.stderr.decode('utf-8', 'replace')}")
    return proc.stdout.decode("utf-8", "replace")


def git_png_size(path: str) -> tuple[int, int]:
    proc = subprocess.run(["git", "show", f"{UNITY_BRANCH}:{path}"],
                          cwd=REPO, capture_output=True)
    head = proc.stdout[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"不是 PNG: {path}")
    return struct.unpack(">II", head[16:24])


# --------------------------------------------------------------- YAML 小工具

_DOC_RE = re.compile(r'^--- !u!(\d+) &(-?\d+)\n(\w+):\n', re.M)


def split_docs(text: str) -> list[tuple[str, int, str]]:
    out = []
    marks = list(_DOC_RE.finditer(text))
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        out.append((m.group(3), int(m.group(2)), text[m.end():end]))
    return out


def decode_unity_str(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw.strip('"')
    return raw


def section(body: str, key: str) -> str:
    """取 `  <key>:` 到下一个同级键之间的文本（列表项 `  - ` 不算同级键）。"""
    m = re.search(rf'^  {re.escape(key)}:\n', body, re.M)
    if not m:
        return ""
    rest = body[m.end():]
    nxt = re.search(r'^  (?!- )\S', rest, re.M)
    return rest[:nxt.start()] if nxt else rest


_GO_REF_RE = re.compile(r'm_GameObject: \{fileID: (-?\d+)\}')

_TILE_ENTRY_RE = re.compile(
    r'- first: \{x: (-?\d+), y: (-?\d+), z: (-?\d+)\}\n'
    r'    second:\n'
    r'((?:      [^\n]*\n)+)',
)
_SPRITE_ENTRY_RE = re.compile(
    r'- m_RefCount: \d+\n'
    r'    m_Data: \{fileID: (-?\d+)(?:, guid: ([0-9a-f]{32}), type: \d+)?\}')


def parse_tilemap_sections(body: str) -> tuple[list, list]:
    """返回 (tiles, sprite_array)；sprite_array 每项为 (fileID, guid|None)。"""
    tiles = []
    for m in _TILE_ENTRY_RE.finditer(section(body, "m_Tiles")):
        si = re.search(r'm_TileSpriteIndex: (\d+)', m.group(4))
        tiles.append((int(m.group(1)), int(m.group(2)), int(si.group(1)) if si else -1))
    arr = [(int(f), g or None)
           for f, g in _SPRITE_ENTRY_RE.findall(section(body, "m_TileSpriteArray"))]
    return tiles, arr


# ------------------------------------------------------------------- 图集 meta

_ATLAS_ENTRY_RE = re.compile(
    r'- serializedVersion: 2\n'
    r'      name: "((?:[^"\\]|\\.)*)"\n'
    r'      rect:\n'
    r'        serializedVersion: 2\n'
    r'        x: (-?\d+)\n'
    r'        y: (-?\d+)\n'
    r'        width: (\d+)\n'
    r'        height: (\d+)\n'
    r'.*?'
    r'      pivot: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+)\}\n'
    r'.*?'
    r'      internalID: (-?\d+)\n',
    re.S,
)


def parse_texture_meta(meta: str) -> dict:
    ppu = re.search(r'spritePixelsToUnits: (\d+)', meta)
    mode = re.search(r'spriteMode: (\d+)', meta)
    info = {
        "ppu": int(ppu.group(1)) if ppu else 100,
        "mode": int(mode.group(1)) if mode else 1,
        "sprites": {},
        "pivot": None,
    }
    for raw_name, rx, ry, rw, rh, px, py, iid in _ATLAS_ENTRY_RE.findall(meta):
        folded = re.sub(r'\n[ \t]*', ' ', raw_name)  # YAML 折行 -> 空格
        try:
            name = json.loads(f'"{folded}"')
        except json.JSONDecodeError:
            name = folded
        info["sprites"][int(iid)] = {
            "name": name,
            "rect": (int(rx), int(ry), int(rw), int(rh)),
            "pivot": (float(px), float(py)),
        }
    sp = re.search(r'spritePivot: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+)\}', meta)
    if sp:
        info["pivot"] = (float(sp.group(1)), float(sp.group(2)))
    return info


_GUID_CACHE: dict[str, str] | None = None


def guid_to_path() -> dict[str, str]:
    """一次性批量建立 guid -> unity 资源路径 的映射（避免逐文件 git show）。"""
    global _GUID_CACHE
    if _GUID_CACHE is not None:
        return _GUID_CACHE
    proc = subprocess.run(
        ["git", "-c", "core.quotepath=false", "grep", "-n", "^guid: ", UNITY_BRANCH,
         "--", "*.png.meta", "*.prefab.meta", "*.asset.meta"],
        cwd=REPO, capture_output=True)
    out: dict[str, str] = {}
    for line in proc.stdout.decode("utf-8", "replace").splitlines():
        parts = line.split(":", 3)
        if len(parts) < 4:
            continue
        _tree, path, _ln, content = parts
        if path.endswith(".meta"):
            path = path[:-5]
        g = content.strip().removeprefix("guid: ").strip()
        if re.fullmatch(r"[0-9a-f]{32}", g):
            out[g] = path
    _GUID_CACHE = out
    return out


_GODOT_ASSET_INDEX: dict[str, str] | None = None


def find_godot_asset(basename: str) -> str | None:
    """在 Godot 工程的 assets/ 下按文件名查找已迁移的资源。"""
    global _GODOT_ASSET_INDEX
    if _GODOT_ASSET_INDEX is None:
        idx = {}
        for root, _dirs, files in os.walk(os.path.join(REPO, "assets")):
            for f in files:
                if f.endswith(".png"):
                    idx.setdefault(f, os.path.join(root, f))
        _GODOT_ASSET_INDEX = idx
    p = _GODOT_ASSET_INDEX.get(basename)
    if p is None:
        return None
    return "res://" + os.path.relpath(p, REPO)


_TEX_CACHE: dict[str, dict] = {}


def texture_info(guid: str) -> dict:
    if guid in _TEX_CACHE:
        return _TEX_CACHE[guid]
    unity_path = guid_to_path().get(guid)
    if unity_path is None:
        sys.exit(f"无法解析贴图 guid: {guid}")
    meta = parse_texture_meta(git_show(unity_path + ".meta"))
    w, h = git_png_size(unity_path)
    basename = os.path.basename(unity_path)
    info = {
        "unity_path": unity_path,
        "basename": basename,
        "godot_path": find_godot_asset(basename),
        "size": (w, h),
        **meta,
    }
    _TEX_CACHE[guid] = info
    return info


def sprite_of(guid: str, file_id: int) -> dict:
    """取某个 sprite 的 rect + pivot（单图模式取整图）。"""
    info = texture_info(guid)
    if file_id in info["sprites"]:
        s = info["sprites"][file_id]
        return {"rect": s["rect"], "pivot": s["pivot"]}
    w, h = info["size"]
    return {"rect": (0, 0, w, h), "pivot": info["pivot"] or (0.5, 0.5)}


# ------------------------------------------------------------ 场景 / 预制体解析

def parse_hierarchy(text: str) -> dict:
    """解析一份 Unity YAML，抽出 GameObject / Transform / SpriteRenderer / BoxCollider2D。"""
    gameobjects, transforms, sprites, boxes = {}, {}, [], []
    for cls, fid, body in split_docs(text):
        if cls == "GameObject":
            name_m = re.search(r'm_Name: (.*)', body)
            gameobjects[fid] = decode_unity_str(name_m.group(1)) if name_m else ""
        elif cls in ("Transform", "RectTransform"):
            go = _GO_REF_RE.search(body)
            father = re.search(r'm_Father: \{fileID: (-?\d+)\}', body)
            pos = re.search(
                r'm_LocalPosition: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+), z: ([\d.eE+-]+)\}', body)
            scl = re.search(
                r'm_LocalScale: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+), z: ([\d.eE+-]+)\}', body)
            transforms[fid] = {
                "gameobject": int(go.group(1)) if go else None,
                "father": int(father.group(1)) if father else 0,
                "pos": tuple(float(v) for v in pos.groups()) if pos else (0.0, 0.0, 0.0),
                "scale": tuple(float(v) for v in scl.groups()) if scl else (1.0, 1.0, 1.0),
            }
        elif cls == "SpriteRenderer":
            go = _GO_REF_RE.search(body)
            spr = re.search(
                r'm_Sprite: \{fileID: (-?\d+), guid: ([0-9a-f]{32}), type: (\d+)\}', body)
            sprites.append({
                "gameobject": int(go.group(1)) if go else None,
                "sprite": (int(spr.group(1)), spr.group(2)) if spr else None,
            })
        elif cls == "BoxCollider2D":
            go = _GO_REF_RE.search(body)
            size = re.search(r'm_Size: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+)\}', body)
            off = re.search(r'm_Offset: \{x: ([\d.eE+-]+), y: ([\d.eE+-]+)\}', body)
            boxes.append({
                "gameobject": int(go.group(1)) if go else None,
                "size": tuple(float(v) for v in size.groups()) if size else None,
                "offset": tuple(float(v) for v in off.groups()) if off else (0.0, 0.0),
            })
    go_transform = {t["gameobject"]: f for f, t in transforms.items() if t["gameobject"]}
    box_of = {b["gameobject"]: b for b in boxes if b["gameobject"]}
    return {"gameobjects": gameobjects, "transforms": transforms,
            "go_transform": go_transform, "sprites": sprites, "boxes": boxes,
            "box_of": box_of}


def world_xform(tfid: int, h: dict, cache: dict) -> tuple[float, float, float, float]:
    """沿 m_Father 累加位置、累乘缩放。"""
    if tfid in cache:
        return cache[tfid]
    cache[tfid] = (0.0, 0.0, 1.0, 1.0)
    t = h["transforms"].get(tfid)
    if t is None:
        return (0.0, 0.0, 1.0, 1.0)
    bx, by, bsx, bsy = world_xform(t["father"], h, cache) if t["father"] else (0.0, 0.0, 1.0, 1.0)
    res = (bx + t["pos"][0] * bsx, by + t["pos"][1] * bsy,
           bsx * t["scale"][0], bsy * t["scale"][1])
    cache[tfid] = res
    return res


# ----------------------------------------------------------------------- 主流程

def build(scene: dict) -> dict:
    # --- 地形：收集用到的切片，建立「(源贴图, 源 rect) -> 打包序号」映射
    tile_key_to_index: dict[tuple, int] = {}
    tiles_out: list[dict] = []

    layers = {}
    skipped: dict[str, list] = {}
    for tm in scene["tilemaps"]:
        go = tm["gameobject"]
        name = scene["gameobjects"].get(go, "?")
        kind = "obstacles" if go in scene["colliders"] else "ground"
        cells = []
        bad = []
        for ux, uy, si in tm["tiles"]:
            if si < 0 or si >= len(tm["sprite_array"]):
                bad.append((ux, uy, si, "bad-index"))
                continue
            iid, guid = tm["sprite_array"][si]
            if guid is None or iid == 0:
                bad.append((ux, uy, si, "blank-sprite"))
                continue
            tex = texture_info(guid)
            spr = sprite_of(guid, iid)
            rx, ry, rw, rh = spr["rect"]
            key = (tex["godot_path"], (rx, ry, rw, rh))
            if key not in tile_key_to_index:
                tile_key_to_index[key] = len(tiles_out)
                th = tex["size"][1]
                tiles_out.append({
                    "src": tex["godot_path"],
                    "rect": [rx, th - ry - rh, rw, rh],
                })
            cells.append((ux, -uy - 1, tile_key_to_index[key]))
        layers[kind] = {"name": name, "cells": cells}
        skipped[kind] = bad

    # --- 道具
    props, zones = [], []
    cache: dict = {}
    scene_go = scene["gameobjects"]

    for sr in scene["sprites"]:
        go = sr["gameobject"]
        name = scene_go.get(go, "?")
        if name in EXCLUDED_PROPS or sr["sprite"] is None:
            continue
        fid, guid = sr["sprite"]
        tfid = scene["go_transform"].get(go)
        ux, uy, sx, sy = world_xform(tfid, scene, cache) if tfid else (0.0, 0.0, 1.0, 1.0)
        entry = make_prop(name, guid, fid, ux, uy, sx, sy, kind_of(name))
        (zones if entry["kind"] == "pond" else props).append(entry)

    # 预制体实例（树木等）
    prefab_log: list[tuple[str, int, int]] = []
    for pi in scene["prefab_instances"]:
        guid = pi["source_prefab"][0] if pi["source_prefab"] else None
        if guid is None:
            continue
        prefab_path = guid_to_path().get(guid)
        if prefab_path is None or not prefab_path.endswith(".prefab"):
            continue
        ph = parse_hierarchy(git_show(prefab_path))
        root = next((f for f, t in ph["transforms"].items() if t["father"] == 0), None)
        if root is None:
            continue
        root_name = ph["gameobjects"].get(ph["transforms"][root]["gameobject"], "?")
        if root_name in EXCLUDED_PROPS:
            continue
        mods = dict(pi["mods"])
        lx = float(mods.get("m_LocalPosition.x", 0.0))
        ly = float(mods.get("m_LocalPosition.y", 0.0))
        px_, py_, psx, psy = world_xform(pi["parent"], scene, cache) if pi["parent"] \
            else (0.0, 0.0, 1.0, 1.0)
        inst_x, inst_y = px_ + lx * psx, py_ + ly * psy
        root_wx, root_wy, root_wsx, root_wsy = world_xform(root, ph, {})

        emitted = 0
        for s in ph["sprites"]:
            if s["sprite"] is None:
                continue
            tf = ph["go_transform"].get(s["gameobject"])
            wx, wy, wsx, wsy = world_xform(tf, ph, {}) if tf else (0.0, 0.0, 1.0, 1.0)
            # 相对预制体根的位置（根自身 localPosition 会被实例覆盖，故需减去）
            rel_x = wx - root_wx
            rel_y = wy - root_wy
            entry = make_prop(root_name, s["sprite"][1], s["sprite"][0],
                              inst_x + rel_x, inst_y + rel_y,
                              wsx, wsy, "tree", ph["box_of"].get(s["gameobject"]))
            props.append(entry)
            emitted += 1
        prefab_log.append((root_name, emitted, len(ph["sprites"])))

    return {
        "unity_px_per_unit": UNITY_PX_PER_UNIT,
        "tile_size": int(UNITY_PX_PER_UNIT),
        "packed_columns": PACKED_COLUMNS,
        "tiles": tiles_out,
        "ground": [list(c) for c in layers.get("ground", {}).get("cells", [])],
        "obstacles": [list(c) for c in layers.get("obstacles", {}).get("cells", [])],
        "props": props,
        "zones": zones,
        "_skipped": skipped,
        "_prefab_log": prefab_log,
    }


def texture_info_guid_of_tile_atlas() -> str:
    p = guid_to_path()
    for g, path in p.items():
        if path == TILE_ATLAS_PATH:
            return g
    sys.exit("未找到瓦片图集的 guid")


def kind_of(name: str) -> str:
    if name == "池塘":
        return "pond"
    if name == "屋檐":
        return "eaves"
    return "town"


# 物理层（MIGRATION_PLAN §12.1）：1 world / 4 eaves / 5 town / 7 pond。
# 玩家 collision_mask 只含 1 world，所以能挡住玩家的道具必须带 world 位。
_LAYER_OF_KIND = {"tree": 1, "town": 1, "eaves": 1 | 8, "pond": 7}


def make_prop(name: str, guid: str, file_id: int, ux: float, uy: float,
              sx: float, sy: float, kind: str, box: dict | None = None) -> dict:
    info = texture_info(guid)
    spr = sprite_of(guid, file_id)
    rx, ry, rw, rh = spr["rect"]
    pvx, pvy = spr["pivot"]
    tw, th = info["size"]
    region = [rx, th - ry - rh, rw, rh]
    # 目标显示尺寸（Godot px）= 贴图尺寸 / PPU * Unity 缩放 * 64
    k = UNITY_PX_PER_UNIT / info["ppu"]
    draw_w, draw_h = rw * k * abs(sx), rh * k * abs(sy)
    if box and box["size"]:
        # Unity BoxCollider2D 的 size/offset 在局部空间，随 transform 缩放
        col_w = box["size"][0] * abs(sx) * UNITY_PX_PER_UNIT
        col_h = box["size"][1] * abs(sy) * UNITY_PX_PER_UNIT
        col_x = box["offset"][0] * sx * UNITY_PX_PER_UNIT
        col_y = -box["offset"][1] * sy * UNITY_PX_PER_UNIT
    else:
        col_w, col_h, col_x, col_y = draw_w, draw_h, 0.0, 0.0
    return {
        "name": name,
        "kind": kind,
        "texture": info["godot_path"],
        "region": region,
        "pos": [ux * UNITY_PX_PER_UNIT, -uy * UNITY_PX_PER_UNIT],
        "scale": [draw_w / rw, draw_h / rh],
        "offset": [rw * (0.5 - pvx), rh * (pvy - 0.5)],
        "flip_h": sx < 0,
        "flip_v": sy < 0,
        "collision_layer": _LAYER_OF_KIND[kind],
        "collision_size": [col_w, col_h],
        "collision_offset": [col_x, col_y],
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true")
    args = ap.parse_args()

    scene = parse_hierarchy(git_show(SCENE_PATH))
    # parse_hierarchy 用同一套键名，补上 tilemap 专有解析
    scene["colliders"] = set()
    scene["tilemaps"] = []
    for cls, fid, body in split_docs(git_show(SCENE_PATH)):
        if cls == "TilemapCollider2D":
            go = _GO_REF_RE.search(body)
            if go:
                scene["colliders"].add(int(go.group(1)))
        elif cls == "Tilemap":
            go = _GO_REF_RE.search(body)
            tiles, arr = parse_tilemap_sections(body)
            scene["tilemaps"].append({
                "gameobject": int(go.group(1)) if go else None,
                "tiles": tiles,
                "sprite_array": arr,
            })
    scene["prefab_instances"] = []
    for cls, fid, body in split_docs(git_show(SCENE_PATH)):
        if cls == "PrefabInstance":
            parent = re.search(r'm_TransformParent: \{fileID: (-?\d+)\}', body)
            mods = re.findall(r'propertyPath: ([A-Za-z0-9_.]+)\n\s*value: ([\d.eE+-]+)', body)
            src = re.search(
                r'm_SourcePrefab: \{fileID: (-?\d+), guid: ([0-9a-f]{32}), type: (\d+)\}', body)
            scene["prefab_instances"].append({
                "parent": int(parent.group(1)) if parent else 0,
                "mods": mods,
                "source_prefab": (src.group(2), src.group(3)) if src else None,
            })

    data = build(scene)

    _t = texture_info(texture_info_guid_of_tile_atlas())
    print(f"DEBUG tilemaps={len(scene['tilemaps'])} "
          f"tiles={[len(t['tiles']) for t in scene['tilemaps']]} "
          f"arr={[len(t['sprite_array']) for t in scene['tilemaps']]} "
          f"colliders={len(scene['colliders'])} "
          f"atlas_sprites={len(_t['sprites'])} atlas_size={_t['size']} ppu={_t['ppu']}")
    print(f"地面格数      : {len(data['ground'])}")
    print(f"障碍格数      : {len(data['obstacles'])}")
    for k, v in data["_skipped"].items():
        print(f"跳过({k})   : {len(v)} {v[:5]}")
    print(f"图集去重切片数: {len(data['tiles'])}")
    for t in data["tiles"]:
        print(f"    tile[{data['tiles'].index(t):2d}] {os.path.basename(t['src'])[:20]:22s} rect={t['rect']}")
    print(f"道具数        : {len(data['props'])}")
    print(f"预制体实例    : {data['_prefab_log']}")
    print(f"区域数        : {len(data['zones'])}")
    kinds: dict[str, int] = {}
    for p in data["props"] + data["zones"]:
        kinds[p["name"]] = kinds.get(p["name"], 0) + 1
    print(f"道具构成      : {kinds}")
    for p in data["props"] + data["zones"]:
        print(f"    {p['kind']:6s} {p['name']:8s} pos={[round(v, 1) for v in p['pos']]} "
              f"scale={[round(v, 3) for v in p['scale']]} "
              f"col={[round(v, 1) for v in p['collision_size']]}"
              f"@{[round(v, 1) for v in p['collision_offset']]} L{p['collision_layer']} "
              f"flip={p['flip_h']},{p['flip_v']} tex={os.path.basename(p['texture'] or '')}")

    if args.probe:
        return
    data.pop("_skipped", None)
    data.pop("_prefab_log", None)
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    print(f"\n已写出 {os.path.relpath(OUT_JSON, REPO)}")


if __name__ == "__main__":
    main()
