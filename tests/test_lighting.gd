extends SceneTree
## Phase 8 无头测试：验证场景环境光、玩家/火焰/传送圈点光源。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const TELEPORT_SCENE := "res://scenes/effects/teleport_ring.tscn"
const FIRE_SCENE := "res://scenes/effects/fire.tscn"

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
	print("=== Phase 8 2D 光照无头测试 ===")
	var town := (load(TOWN_SCENE) as PackedScene).instantiate()
	root.add_child(town)
	await process_frame

	var lighting := town.get_node_or_null("Lighting") as CanvasModulate
	var player := town.get_node_or_null("World/Entities/Player")
	var teleport := town.get_node_or_null("World/TeleportRing")
	_check("城镇环境光存在", lighting != null)
	_check("城镇环境光不是纯白", lighting != null and lighting.color != Color.WHITE,
		"color=%s" % (lighting.color if lighting else "null"))
	_check("玩家存在", player != null)
	if player != null:
		var player_light := player.get_node_or_null("PointLight2D") as PointLight2D
		_check("玩家点光源存在", player_light != null)
		_check("玩家点光源有柔光纹理", player_light != null and player_light.texture != null)
		_check("玩家点光源能量有效", player_light != null and player_light.energy > 0.0)

	_check("城镇传送圈存在", teleport != null)
	if teleport != null:
		var teleport_light := teleport.get_node_or_null("PointLight2D") as PointLight2D
		_check("传送圈点光源存在", teleport_light != null)
		_check("传送圈点光源有柔光纹理", teleport_light != null and teleport_light.texture != null)

	var teleport_scene := (load(TELEPORT_SCENE) as PackedScene).instantiate()
	_check("传送圈场景可独立加载", teleport_scene != null)
	teleport_scene.free()

	var fire := (load(FIRE_SCENE) as PackedScene).instantiate()
	root.add_child(fire)
	await process_frame
	var sprite := fire.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var fire_light := fire.get_node_or_null("PointLight2D") as PointLight2D
	_check("火焰动画存在", sprite != null)
	_check("火焰动画为 120 帧", sprite != null and sprite.sprite_frames.get_frame_count(&"fire") == 120)
	_check("火焰点光源存在", fire_light != null)
	_check("火焰点光源有柔光纹理", fire_light != null and fire_light.texture != null)
	_check("火焰点光源能量有效", fire_light != null and fire_light.energy > 0.0)
	_check("火焰只有单一有效光源", fire != null and _count_point_lights(fire) == 1)

	fire.queue_free()
	_finish()


func _count_point_lights(node: Node) -> int:
	var count := 1 if node is PointLight2D else 0
	for child in node.get_children():
		count += _count_point_lights(child)
	return count


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
