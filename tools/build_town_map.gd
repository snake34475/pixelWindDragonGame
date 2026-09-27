extends SceneTree
## 由 resources/world/town_map.json 生成瓦片集与 TownMap 场景。
##
## 用 tools/build_town_map.sh 跑（三步：写打包图集 → --import → 建资源）。
## 本脚本是幂等的：第一次只写出打包 PNG 并提示需要导入，导入后再跑才生成 .tres/.tscn。

const JSON_PATH := "res://resources/world/town_map.json"
const PACKED_PNG := "res://assets/environment/tiles/town_tiles.png"
const TILESET_PATH := "res://resources/world/town_tileset.tres"
const SCENE_PATH := "res://scenes/levels/town_map.tscn"
const WATER_ZONE_SCRIPT := preload("res://scripts/world/water_zone.gd")

## TileSet 的物理层 0 绑到 1 world，与 MIGRATION_PLAN §12.1 一致。
const PHYSICS_LAYER_WORLD := 1


func _initialize() -> void:
	var data := _read_json()
	if data.is_empty():
		quit(1)
		return

	var cols := int(data["packed_columns"])
	var tile_size := int(data["tile_size"])
	var tiles: Array = data["tiles"]

	_write_packed_atlas(tiles, cols, tile_size)

	var tex := _load_packed_texture()
	if tex == null:
		print("已写出 %s，但 Godot 还没导入它。" % PACKED_PNG)
		print("请用 tools/build_town_map.sh 重新生成（其中包含 --import 步骤）。")
		quit(0)
		return

	var tile_set := _build_tile_set(tex, tiles, cols, tile_size)
	var err := ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("保存 %s 失败: %d" % [TILESET_PATH, err])
		quit(1)
		return
	# 让 pack 时把瓦片集写成 ext_resource，而不是把整份内嵌进场景
	tile_set.resource_path = TILESET_PATH

	var root := _build_scene(tile_set, data, cols)
	var packed := PackedScene.new()
	err = packed.pack(root)
	root.free()
	if err != OK:
		push_error("打包场景失败: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, SCENE_PATH)
	if err != OK:
		push_error("保存 %s 失败: %d" % [SCENE_PATH, err])
		quit(1)
		return

	print("已写出 %s 与 %s" % [TILESET_PATH, SCENE_PATH])
	print("  tiles=%d ground=%d obstacles=%d props=%d zones=%d" % [
		tiles.size(), data["ground"].size(), data["obstacles"].size(),
		data["props"].size(), data["zones"].size()])
	quit(0)


# ------------------------------------------------------------------ 读数据 / 图集

func _read_json() -> Dictionary:
	if not FileAccess.file_exists(JSON_PATH):
		push_error("找不到 %s，请先运行 tools/convert_unity_scene.py" % JSON_PATH)
		return {}
	var fh := FileAccess.open(JSON_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s 解析失败" % JSON_PATH)
		return {}
	return parsed


## Unity 图集里的切片不在 64 网格上（如 y=224），无法直接当 TileSetAtlasSource 用，
## 所以把用到的切片重新打包成一张规整图集：每格 tile_size 见方，packed_columns 列。
func _write_packed_atlas(tiles: Array, cols: int, tile_size: int) -> void:
	var rows := int(ceil(float(tiles.size()) / float(cols)))
	var out := Image.create_empty(cols * tile_size, rows * tile_size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		var r: Array = t["rect"]
		var src := Image.load_from_file(ProjectSettings.globalize_path(String(t["src"])))
		if src == null:
			push_error("无法读取贴图: %s" % String(t["src"]))
			continue
		var region := src.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		if region.get_width() != tile_size or region.get_height() != tile_size:
			# 例：石障 32x32 / PPU 32 也是 1 格，按最近邻放大到格子尺寸
			region.resize(tile_size, tile_size, Image.INTERPOLATE_NEAREST)
		# blit_rect 要求源与目标格式一致，源 PNG 多为 RGB8/RGBA8 之外的格式
		if region.get_format() != Image.FORMAT_RGBA8:
			region.convert(Image.FORMAT_RGBA8)
		out.blit_rect(region, Rect2i(0, 0, tile_size, tile_size),
			Vector2i((i % cols) * tile_size, int(i / cols) * tile_size))
	out.save_png(ProjectSettings.globalize_path(PACKED_PNG))


func _load_packed_texture() -> Texture2D:
	if not FileAccess.file_exists(PACKED_PNG + ".import"):
		return null
	return ResourceLoader.load(PACKED_PNG) as Texture2D


# ------------------------------------------------------------------------ 瓦片集

func _build_tile_set(tex: Texture2D, tiles: Array, cols: int, tile_size: int) -> TileSet:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(tile_size, tile_size)
	for i in tiles.size():
		atlas.create_tile(_coords_of(i, cols))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, PHYSICS_LAYER_WORLD)
	tile_set.add_source(atlas, 0)

	# Unity 侧 m_ColliderType = Sprite，即「整块 sprite 矩形」；这里每个瓦片铺满整格。
	# Ground 层把 collision_enabled 关掉，所以共用一个 TileSet 也不会误挡。
	var half := tile_size / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
	for i in tiles.size():
		var td := atlas.get_tile_data(_coords_of(i, cols), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	return tile_set


func _coords_of(index: int, cols: int) -> Vector2i:
	return Vector2i(index % cols, int(index / cols))


# ------------------------------------------------------------------------ 场景

func _build_scene(tile_set: TileSet, data: Dictionary, cols: int) -> Node2D:
	var root := Node2D.new()
	root.name = "TownMap"
	# 让 World 的 Y-sort 能递归展开到 Props/Zones（中间节点也必须开 y_sort）
	root.y_sort_enabled = true

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	ground.collision_enabled = false
	ground.z_index = -2
	root.add_child(ground)
	_fill(ground, data["ground"], cols)

	var obstacles := TileMapLayer.new()
	obstacles.name = "Obstacles"
	obstacles.tile_set = tile_set
	obstacles.collision_enabled = true
	obstacles.z_index = -1
	root.add_child(obstacles)
	_fill(obstacles, data["obstacles"], cols)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	var used := {}
	for p in data["props"]:
		props.add_child(_make_body(p, used))

	var zones := Node2D.new()
	zones.name = "Zones"
	zones.y_sort_enabled = true
	root.add_child(zones)
	for z in data["zones"]:
		zones.add_child(_make_zone(z))

	# PackedScene.pack() 会忽略 owner 未指向根节点的子节点，必须显式指派
	_assign_owner(root, root)
	return root


func _assign_owner(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_assign_owner(c, owner_node)


func _fill(layer: TileMapLayer, cells: Array, cols: int) -> void:
	for c in cells:
		layer.set_cell(Vector2i(int(c[0]), int(c[1])), 0, _coords_of(int(c[2]), cols))


func _make_body(p: Dictionary, used: Dictionary) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = _unique_name(String(p["name"]), used)
	body.position = _vec(p["pos"])
	body.collision_layer = int(p["collision_layer"])
	body.collision_mask = 0
	body.add_child(_make_sprite(p))
	body.add_child(_make_collider(p))
	return body


func _make_zone(z: Dictionary) -> Area2D:
	var area := Area2D.new()
	area.name = _sanitize(String(z["name"]))
	area.position = _vec(z["pos"])
	area.collision_layer = int(z["collision_layer"])
	if String(z["kind"]) == "pond":
		area.collision_mask = 2
		area.set_script(WATER_ZONE_SCRIPT)
	area.add_child(_make_sprite(z))
	area.add_child(_make_collider(z))
	return area


## 位置 = Unity 世界坐标 ×64（y 取反）；region 从源贴图取切片；
## offset 用未缩放的切片尺寸表示轴心偏移（见 convert_unity_scene.make_prop 的推导）。
func _make_sprite(p: Dictionary) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = load(String(p["texture"]))
	spr.region_enabled = true
	var r: Array = p["region"]
	spr.region_rect = Rect2(r[0], r[1], r[2], r[3])
	spr.scale = _vec(p["scale"])
	spr.offset = _vec(p["offset"])
	spr.flip_h = bool(p["flip_h"])
	spr.flip_v = bool(p["flip_v"])
	return spr


func _make_collider(p: Dictionary) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = _vec(p["collision_size"])
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = shape
	col.position = _vec(p["collision_offset"])
	return col


func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _sanitize(raw: String) -> String:
	var out := raw.strip_edges()
	for bad in ["\"", ":", "/", "@", "%", "."]:
		out = out.replace(bad, "_")
	return out if out != "" else "Prop"


func _unique_name(raw: String, used: Dictionary) -> String:
	var n := _sanitize(raw)
	if used.has(n):
		used[n] += 1
		return "%s_%d" % [n, used[n]]
	used[n] = 1
	return n
