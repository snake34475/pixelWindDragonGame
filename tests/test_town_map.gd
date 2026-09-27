extends SceneTree
## Phase 2 无头测试：验证由 town_map.json 生成的瓦片地形、道具、碰撞与 Y-sort。
##
## 运行：
##   godot --headless --path . --script res://tests/test_town_map.gd
## 退出码 0 = 全部通过，1 = 有失败项。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const JSON_PATH := "res://resources/world/town_map.json"
const TILE := 64

var _checks: int = 0
var _failures: int = 0
var _data: Dictionary


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s%s" % [label, ("  -> " + detail) if detail != "" else ""])


func _read_json() -> Dictionary:
	if not FileAccess.file_exists(JSON_PATH):
		return {}
	var fh := FileAccess.open(JSON_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## 格 (gx, gy) 在 Godot 世界坐标里的中心
func _center(cell: Array) -> Vector2:
	return Vector2((int(cell[0]) + 0.5) * TILE, (int(cell[1]) + 0.5) * TILE)


func _run() -> void:
	print("=== Phase 2 瓦片世界无头测试 ===")

	_data = _read_json()
	_check("town_map.json 可读", not _data.is_empty())
	if _data.is_empty():
		_finish()
		return
	var cols := int(_data["packed_columns"])

	# ---------- 1. 场景结构 ----------
	print("\n[1] 场景结构")
	var packed := load(TOWN_SCENE)
	_check("town.tscn 能加载", packed != null)
	if packed == null:
		_finish()
		return
	var town: Node = packed.instantiate()
	root.add_child(town)
	await physics_frame
	await physics_frame

	var world := town.get_node_or_null("World") as Node2D
	_check("World 存在", world != null)
	_check("World.y_sort_enabled = true", world != null and world.y_sort_enabled)

	var map := town.get_node_or_null("World/TownMap") as Node2D
	_check("TownMap 实例存在", map != null)
	if map == null:
		_finish()
		return
	_check("TownMap.y_sort_enabled = true", map.y_sort_enabled)

	var ground := map.get_node_or_null("Ground") as TileMapLayer
	var obstacles := map.get_node_or_null("Obstacles") as TileMapLayer
	var props := map.get_node_or_null("Props") as Node2D
	var zones := map.get_node_or_null("Zones") as Node2D
	_check("Ground 存在", ground != null)
	_check("Obstacles 存在", obstacles != null)
	_check("Props 存在", props != null)
	_check("Zones 存在", zones != null)
	if ground == null or obstacles == null or props == null or zones == null:
		_finish()
		return

	_check("Ground 不参与碰撞", ground.collision_enabled == false)
	_check("Obstacles 参与碰撞", obstacles.collision_enabled == true)
	_check("Props 参与 Y-sort", props.y_sort_enabled)
	var entities := town.get_node_or_null("World/Entities") as Node2D
	_check("Entities 存在", entities != null)
	_check("Entities 参与 Y-sort", entities != null and entities.y_sort_enabled)

	# ---------- 2. 格子数量与坐标 ----------
	print("\n[2] 地形格子")
	var want_ground: int = _data["ground"].size()
	var want_obstacles: int = _data["obstacles"].size()
	_check("Ground 格数 = %d" % want_ground, ground.get_used_cells().size() == want_ground,
		"实际 %d" % ground.get_used_cells().size())
	_check("Obstacles 格数 = %d" % want_obstacles,
		obstacles.get_used_cells().size() == want_obstacles,
		"实际 %d" % obstacles.get_used_cells().size())

	# 抽 3 个格子核对 atlas 坐标（JSON 里第 3 列是打包序号）
	var sampled := 0
	var sample_ok := true
	var sample_detail := ""
	for cell in _data["ground"]:
		if sampled >= 3:
			break
		var c := Vector2i(int(cell[0]), int(cell[1]))
		var idx := int(cell[2])
		var want := Vector2i(idx % cols, int(idx / cols))
		var got := ground.get_cell_atlas_coords(c)
		if got != want:
			sample_ok = false
			sample_detail = "格 %s 期望 %s 实际 %s" % [c, want, got]
		sampled += 1
	_check("抽样 %d 个地面格的 atlas 坐标一致" % sampled, sample_ok, sample_detail)

	# ---------- 3. 碰撞层 ----------
	print("\n[3] 碰撞设置")
	var ts: TileSet = obstacles.tile_set
	_check("Obstacles 有 physics layer", ts != null and ts.get_physics_layers_count() >= 1)
	_check("physics layer 0 绑定 1 world",
		ts != null and ts.get_physics_layer_collision_layer(0) == 1,
		"实际 %d" % (ts.get_physics_layer_collision_layer(0) if ts else -1))

	var src := ts.get_source(0) as TileSetAtlasSource
	var first_obs := Vector2i(int(_data["obstacles"][0][0]), int(_data["obstacles"][0][1]))
	var coords := obstacles.get_cell_atlas_coords(first_obs)
	var td := src.get_tile_data(coords, 0)
	_check("障碍瓦片定义了碰撞多边形",
		td != null and td.get_collision_polygons_count(0) > 0)

	# 空间点查询：障碍格中心应命中，纯地面格中心不应命中
	var space := map.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	q.position = _center(_data["obstacles"][0])
	_check("障碍格中心能查到 layer 1 碰撞体", space.intersect_point(q, 8).size() > 0)

	var obstacle_set := {}
	for c in _data["obstacles"]:
		obstacle_set[Vector2i(int(c[0]), int(c[1]))] = true
	var ground_only: Array = []
	for c in _data["ground"]:
		var key := Vector2i(int(c[0]), int(c[1]))
		if not obstacle_set.has(key):
			ground_only.append(c)
	_check("存在纯地面格", ground_only.size() > 0)
	if ground_only.size() > 0:
		q.position = _center(ground_only[0])
		_check("纯地面格中心查不到 layer 1 碰撞体", space.intersect_point(q, 8).size() == 0)

	# ---------- 4. 道具与区域 ----------
	print("\n[4] 道具与区域")
	var want_props: int = _data["props"].size()
	_check("Props 子节点数 = %d" % want_props, props.get_child_count() == want_props,
		"实际 %d" % props.get_child_count())
	var prop_ok := true
	var prop_detail := ""
	for p in props.get_children():
		if p.get_node_or_null("Sprite2D") == null or p.get_node_or_null("CollisionShape2D") == null:
			prop_ok = false
			prop_detail = "%s 缺少 Sprite2D 或 CollisionShape2D" % p.name
	_check("每个道具都带 Sprite2D + CollisionShape2D", prop_ok, prop_detail)

	var want_zones: int = _data["zones"].size()
	_check("Zones 子节点数 = %d" % want_zones, zones.get_child_count() == want_zones,
		"实际 %d" % zones.get_child_count())
	var pond: Node = zones.get_child(0) if want_zones > 0 else null
	_check("池塘是 Area2D（不阻挡玩家）", pond is Area2D)
	_check("池塘碰撞层 = 7 pond", pond != null and pond.collision_layer == 7,
		"实际 %d" % (pond.collision_layer if pond else -1))

	# 道具碰撞层：树木/朱门必须含 1 world（否则挡不住玩家）
	var tree_layers := {}
	for p in props.get_children():
		tree_layers[p.name] = p.collision_layer
	var all_block := true
	for p in props.get_children():
		if p.collision_layer & 1 == 0:
			all_block = false
	_check("所有道具碰撞层都含 1 world（能挡住玩家）", all_block, str(tree_layers))

	# ---------- 5. 玩家被障碍挡住 ----------
	print("\n[5] 玩家被障碍阻挡")
	var player := town.get_node_or_null("World/Entities/Player") as CharacterBody2D
	_check("Player 存在", player != null)
	if player == null:
		_finish()
		return

	# 找一块下方为空、且周围没有道具的障碍格
	var picked: Array = []
	for c in _data["obstacles"]:
		var key := Vector2i(int(c[0]), int(c[1]))
		if obstacle_set.has(Vector2i(key.x, key.y + 1)):
			continue
		q.position = _center(c) + Vector2(0, 96)
		if space.intersect_point(q, 8).size() > 0:
			continue
		picked = c
		break
	_check("找到可用于阻挡测试的障碍格", not picked.is_empty())
	if picked.is_empty():
		_finish()
		return

	var target := _center(picked)
	var surface_y := target.y + TILE / 2.0 + TILE / 2.0  # 障碍下沿 + 半个玩家高
	player.global_position = target + Vector2(0, 96)
	player.velocity = Vector2.ZERO
	await physics_frame

	Input.action_press("move_up")
	for i in 90:
		await physics_frame
	Input.action_release("move_up")
	await physics_frame

	var end_y := player.global_position.y
	_check("向上顶到障碍后停在表面（未穿透）", end_y >= surface_y - 2.0,
		"终点 y=%.1f 表面 y=%.1f" % [end_y, surface_y])
	_check("确实向障碍移动过（不是原地不动）", end_y < target.y + 96.0 - 4.0,
		"终点 y=%.1f 起点 y=%.1f" % [end_y, target.y + 96.0])
	_check("未穿过障碍中心", end_y > target.y, "终点 y=%.1f 障碍中心 y=%.1f" % [end_y, target.y])

	_finish()


func _finish() -> void:
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)