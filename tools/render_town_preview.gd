extends SceneTree
## 无头渲染一张地图预览图，用于目视验收（不需要窗口/显示设备）。
##
## 运行：
##   godot --headless --path . --script res://tools/render_town_preview.gd -- /tmp/town_preview.png
##
## 合成规则与运行时一致：
##   地形格 (gx,gy) 覆盖世界矩形 [gx*64,(gx+1)*64) × [gy*64,(gy+1)*64)
##   Sprite2D 以 pos 为中心，先按 region 取切片，再乘 scale，offset 也在缩放空间内

const JSON_PATH := "res://resources/world/town_map.json"
const PACKED_PNG := "res://assets/environment/tiles/town_tiles.png"
const TILE := 64
const BG := Color(0.169, 0.216, 0.176, 1.0)

var _data: Dictionary


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "/tmp/town_preview.png"

	_data = _read_json()
	if _data.is_empty():
		quit(1)
		return

	var rects := _collect_rects()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for r in rects:
		min_x = min(min_x, r.position.x)
		min_y = min(min_y, r.position.y)
		max_x = max(max_x, r.position.x + r.size.x)
		max_y = max(max_y, r.position.y + r.size.y)

	var pad := 32.0
	var ox := int(floor(min_x - pad))
	var oy := int(floor(min_y - pad))
	var w := int(ceil(max_x + pad)) - ox
	var h := int(ceil(max_y + pad)) - oy

	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)

	_blit_cells(img, ox, oy, _data["ground"])
	_blit_cells(img, ox, oy, _data["obstacles"])

	var items: Array = []
	for p in _data["props"]:
		items.append(p)
	for z in _data["zones"]:
		items.append(z)
	# Y-sort：y 小的先画（在后面），y 大的后画（遮住前面）
	items.sort_custom(func(a, b): return float(a["pos"][1]) < float(b["pos"][1]))
	for it in items:
		_blit_prop(img, ox, oy, it)

	img.save_png(out_path)
	print("预览图已写出: %s  (%dx%d, 原点偏移 %d,%d)" % [out_path, w, h, ox, oy])
	print("  ground=%d obstacles=%d props=%d zones=%d" % [
		_data["ground"].size(), _data["obstacles"].size(),
		_data["props"].size(), _data["zones"].size()])
	quit(0)


func _read_json() -> Dictionary:
	if not FileAccess.file_exists(JSON_PATH):
		return {}
	var fh := FileAccess.open(JSON_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _collect_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for key in ["ground", "obstacles"]:
		for c in _data[key]:
			out.append(Rect2(int(c[0]) * TILE, int(c[1]) * TILE, TILE, TILE))
	for key in ["props", "zones"]:
		for p in _data[key]:
			out.append(_prop_rect(p))
	return out


## Sprite2D 在世界里的绘制矩形
func _prop_rect(p: Dictionary) -> Rect2:
	var r: Array = p["region"]
	var s: Array = p["scale"]
	var o: Array = p["offset"]
	var w := float(r[2]) * float(s[0])
	var h := float(r[3]) * float(s[1])
	var px := float(p["pos"][0]) + float(o[0]) * float(s[0]) - w / 2.0
	var py := float(p["pos"][1]) + float(o[1]) * float(s[1]) - h / 2.0
	return Rect2(px, py, w, h)


func _blit_cells(img: Image, ox: int, oy: int, cells: Array) -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(PACKED_PNG))
	if atlas == null:
		return
	var cols := int(_data["packed_columns"])
	for c in cells:
		var idx := int(c[2])
		var src := atlas.get_region(Rect2i((idx % cols) * TILE, int(idx / cols) * TILE, TILE, TILE))
		_blit(img, src, Rect2i(int(c[0]) * TILE - ox, int(c[1]) * TILE - oy, TILE, TILE))


func _blit_prop(img: Image, ox: int, oy: int, p: Dictionary) -> void:
	var tex := Image.load_from_file(ProjectSettings.globalize_path(String(p["texture"])))
	if tex == null:
		return
	var r: Array = p["region"]
	var region := tex.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	if bool(p["flip_h"]):
		region.flip_x()
	if bool(p["flip_v"]):
		region.flip_y()

	var dst := _prop_rect(p)
	var dw := int(round(dst.size.x))
	var dh := int(round(dst.size.y))
	if dw <= 0 or dh <= 0:
		return
	if dw != region.get_width() or dh != region.get_height():
		region.resize(dw, dh, Image.INTERPOLATE_NEAREST)
	_blit(img, region, Rect2i(int(round(dst.position.x)) - ox, int(round(dst.position.y)) - oy, dw, dh))


func _blit(img: Image, src: Image, dst: Rect2i) -> void:
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	# blit_rect 不裁剪越界部分，先和目标图像求交
	var clipped := Rect2i(0, 0, img.get_width(), img.get_height()).intersection(dst)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var offset := clipped.position - dst.position
	# blend_rect 才会按 alpha 合成，blit_rect 是原样拷贝（透明区会盖成黑块）
	img.blend_rect(src, Rect2i(offset, clipped.size), clipped.position)