extends SceneTree
## Phase 3 无头测试：验证 Q 对玩家前方石障的破坏规则。

const TOWN_SCENE := "res://scenes/levels/town.tscn"

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
	print("=== Phase 3 石障破坏无头测试 ===")
	var packed := load(TOWN_SCENE) as PackedScene
	_check("town.tscn 能加载", packed != null)
	if packed == null:
		_finish()
		return

	var town := packed.instantiate()
	root.add_child(town)
	await physics_frame
	await physics_frame

	var player := town.get_node_or_null("World/Entities/Player") as Player
	var obstacles := town.get_node_or_null("World/TownMap/Obstacles") as TileMapLayer
	var ground := town.get_node_or_null("World/TownMap/Ground") as TileMapLayer
	# 不用 `as TileDestructor`：全局 class_name 索引由编辑器缓存生成，首次无头运行
	# 新脚本时不保证已刷新。测试只依赖该节点公开的两个接口。
	var destructor := town.get_node_or_null("World/TileDestructor")
	_check("Player 存在", player != null)
	_check("Obstacles 存在", obstacles != null)
	_check("TileDestructor 存在", destructor != null)
	if player == null or obstacles == null or ground == null or destructor == null:
		_finish()
		return

	var stone := obstacles.get_used_cells()[0]
	var tile_size := Vector2(obstacles.tile_set.tile_size)
	player.facing = Vector2.UP
	player.global_position = obstacles.to_global(obstacles.map_to_local(stone) - player.facing * tile_size)
	var target := destructor.call("target_cell") as Vector2i
	_check("玩家前方目标是石障", target == stone,
		"目标 %s，石障 %s" % [target, stone])
	_check("破坏石障返回 true", bool(destructor.call("try_destroy_in_front")))
	_check("石障 Tile 已清除", obstacles.get_cell_source_id(stone) == -1)
	var effect := obstacles.get_parent().get_node_or_null("StoneBreak") as Node2D
	_check("石障清除时生成碎石特效", effect != null)
	_check("碎石特效位于被清除格中心", effect != null and effect.global_position.is_equal_approx(
		obstacles.to_global(obstacles.map_to_local(stone))))
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if effect else null
	_check("碎石动画为 7 帧", sprite != null and sprite.sprite_frames.get_frame_count(&"break") == 7)
	var textures_loaded := sprite != null
	if sprite != null:
		for i in sprite.sprite_frames.get_frame_count(&"break"):
			textures_loaded = textures_loaded and sprite.sprite_frames.get_frame_texture(&"break", i) != null
	_check("碎石动画帧贴图均已加载", textures_loaded)
	await physics_frame

	var ground_only := Vector2i.ZERO
	for cell in ground.get_used_cells():
		if obstacles.get_cell_source_id(cell) == -1 and cell != stone:
			ground_only = cell
			break
	_check("找到非石障地面格", ground_only != Vector2i.ZERO)
	if ground_only != Vector2i.ZERO:
		player.global_position = obstacles.to_global(obstacles.map_to_local(ground_only) - player.facing * tile_size)
		_check("非石障目标返回 false", not bool(destructor.call("try_destroy_in_front")))
		_check("非石障地面仍存在", ground.get_cell_source_id(ground_only) != -1)

	for i in 45:
		await physics_frame
	_check("碎石动画结束后自动回收", not is_instance_valid(effect))

	_finish()


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
