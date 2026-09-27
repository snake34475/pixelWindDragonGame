extends SceneTree
## Phase 5 无头测试：验证城镇与旱魃地图的双向传送和一次性出生点。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const HANBA_SCENE := "res://scenes/levels/hanba_map.tscn"
const TELEPORT_LAYER := 1 << 5
const PLAYER_LAYER := 1 << 1

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s%s" % [label, (" -> " + detail) if detail != "" else ""])


func _run() -> void:
	print("=== Phase 5 传送圈 / 多场景无头测试 ===")
	var town_packed := load(TOWN_SCENE) as PackedScene
	var hanba_packed := load(HANBA_SCENE) as PackedScene
	var frames := load("res://resources/effects/teleport_frames.tres") as SpriteFrames
	_check("town.tscn 能加载", town_packed != null)
	_check("hanba_map.tscn 能加载", hanba_packed != null)
	_check("传送圈帧资源能加载", frames != null)
	if town_packed == null or hanba_packed == null or frames == null:
		_finish()
		return
	_check("传送圈动画为 25 帧", frames.get_frame_count(&"idle") == 25)
	var textures_loaded := true
	for i in frames.get_frame_count(&"idle"):
		textures_loaded = textures_loaded and frames.get_frame_texture(&"idle", i) != null
	_check("传送圈所有帧贴图已加载", textures_loaded)

	var town := town_packed.instantiate()
	root.add_child(town)
	current_scene = town
	await process_frame
	await physics_frame

	var town_ring := town.get_node_or_null("World/TeleportRing") as TeleportRing
	var town_player := town.get_node_or_null("World/Entities/Player") as Player
	var town_marker := town.get_node_or_null("World/SpawnPoints/town_arrival") as Marker2D
	_check("城镇传送圈存在", town_ring != null)
	_check("城镇玩家存在", town_player != null)
	_check("城镇出生点存在", town_marker != null)
	if town_ring == null or town_player == null or town_marker == null:
		_finish()
		return
	_check("城镇传送圈只检测玩家层", town_ring.collision_mask == PLAYER_LAYER,
		"mask=%d" % town_ring.collision_mask)
	_check("城镇传送圈位于 teleport 层", (town_ring.collision_layer & TELEPORT_LAYER) != 0,
		"layer=%d" % town_ring.collision_layer)
	_check("城镇传送目标为旱魃地图", town_ring.target_scene_path == HANBA_SCENE,
		town_ring.target_scene_path)
	_check("城镇出生点位于传送圈上方 1 格",
		town_marker.global_position.is_equal_approx(town_ring.global_position + Vector2(0, -64)),
		"marker=%s ring=%s" % [town_marker.global_position, town_ring.global_position])
	var obstacle_overlap := _ring_obstacle_overlap(
		town_ring, town.get_node_or_null("World/TownMap/Obstacles") as TileMapLayer)
	_check("城镇传送圈视觉范围不压石障", obstacle_overlap.is_empty(), obstacle_overlap)

	var requested := [false]
	town_ring.teleport_requested.connect(func(_scene_path: String, _spawn: StringName) -> void:
		requested[0] = true)
	_check("玩家进入城镇传送圈后请求切换", town_ring.try_teleport(town_player))
	_check("同一次进入不会重复请求", not town_ring.try_teleport(town_player))
	_check("传送请求信号已发出", requested[0])

	var hanba := await _wait_for_scene(HANBA_SCENE)
	_check("已切换到旱魃地图", hanba != null)
	if hanba == null:
		_finish()
		return
	var hanba_player := hanba.get_node_or_null("World/Entities/Player") as Player
	var hanba_marker := hanba.get_node_or_null("World/SpawnPoints/hanba_arrival") as Marker2D
	var hanba_ring := hanba.get_node_or_null("World/TeleportRing") as TeleportRing
	_check("旱魃玩家存在", hanba_player != null)
	_check("旱魃出生点存在", hanba_marker != null)
	_check("旱魃传送圈存在", hanba_ring != null)
	if hanba_player == null or hanba_marker == null or hanba_ring == null:
		_finish()
		return
	_check("玩家落在旱魃出生点", hanba_player.global_position.is_equal_approx(hanba_marker.global_position),
		"player=%s marker=%s" % [hanba_player.global_position, hanba_marker.global_position])
	_check("旱魃传送目标为城镇", hanba_ring.target_scene_path == TOWN_SCENE,
		hanba_ring.target_scene_path)
	_check("旱魃出生点位于传送圈上方 1 格",
		hanba_marker.global_position.is_equal_approx(hanba_ring.global_position + Vector2(0, -64)),
		"marker=%s ring=%s" % [hanba_marker.global_position, hanba_ring.global_position])

	_check("玩家进入旱魃传送圈后请求返回", hanba_ring.try_teleport(hanba_player))
	var returned_town := await _wait_for_scene(TOWN_SCENE)
	_check("已返回城镇", returned_town != null)
	if returned_town != null:
		var returned_player := returned_town.get_node_or_null("World/Entities/Player") as Player
		var returned_marker := returned_town.get_node_or_null("World/SpawnPoints/town_arrival") as Marker2D
		_check("玩家落在城镇出生点",
			returned_player != null and returned_marker != null
			and returned_player.global_position.is_equal_approx(returned_marker.global_position))

	_finish()


func _wait_for_scene(scene_path: String) -> Node:
	for i in 30:
		if current_scene != null and current_scene.scene_file_path == scene_path:
			return current_scene
		await process_frame
	return null


## 返回第一个与传送圈整张精灵相交的石障格；无重叠时返回空字符串。
func _ring_obstacle_overlap(ring: TeleportRing, obstacles: TileMapLayer) -> String:
	if ring == null or obstacles == null:
		return "TeleportRing 或 Obstacles 缺失"
	var sprite := ring.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return "传送圈 SpriteFrames 缺失"
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if texture == null:
		return "传送圈首帧贴图缺失"
	var visual_size := Vector2(
		texture.get_width() * absf(sprite.scale.x),
		texture.get_height() * absf(sprite.scale.y))
	var visual_rect := Rect2(ring.global_position - visual_size / 2.0, visual_size)
	for cell in obstacles.get_used_cells():
		var center := obstacles.to_global(obstacles.map_to_local(cell))
		var cell_rect := Rect2(center - Vector2(32, 32), Vector2(64, 64))
		if visual_rect.intersects(cell_rect):
			return "与石障格 %s 相交" % cell
	return ""


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
