extends SceneTree
## Phase 7 无头测试：验证池塘检测和玩家入水表现。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const POND_LAYER := 1 << 6
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
	print("=== Phase 7 水域表现无头测试 ===")
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
	var pond := town.get_node_or_null("World/TownMap/Zones/池塘") as WaterZone
	_check("Player 存在", player != null)
	_check("池塘 WaterZone 存在", pond != null)
	if player == null or pond == null:
		_finish()
		return
	_check("池塘位于 pond 物理层", (pond.collision_layer & POND_LAYER) != 0,
		"layer=%d" % pond.collision_layer)
	_check("池塘检测玩家层", pond.collision_mask == PLAYER_LAYER,
		"mask=%d" % pond.collision_mask)

	var normal_modulate := player.animated_sprite.modulate
	player.global_position = pond.global_position
	await physics_frame
	await physics_frame
	_check("进入池塘后标记为游泳", player.is_swimming)
	_check("进入池塘后角色颜色改变", player.animated_sprite.modulate != normal_modulate,
		"modulate=%s" % player.animated_sprite.modulate)

	player.global_position = pond.global_position + Vector2(2000, 0)
	await physics_frame
	await physics_frame
	_check("离开池塘后解除游泳", not player.is_swimming)
	_check("离开池塘后恢复角色颜色", player.animated_sprite.modulate.is_equal_approx(normal_modulate),
		"modulate=%s" % player.animated_sprite.modulate)

	for i in 3:
		player.enter_water()
		player.exit_water()
	_check("反复进出后无残留水域计数", not player.is_swimming and player.water_zone_count() == 0,
		"swimming=%s count=%s" % [player.is_swimming, player.water_zone_count()])
	_check("反复进出后颜色完全恢复", player.animated_sprite.modulate.is_equal_approx(normal_modulate))

	_finish()


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
