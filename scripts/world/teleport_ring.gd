class_name TeleportRing
extends Area2D
## 玩家进入后请求切换场景。传送圈只负责触发，不直接移动玩家。

signal teleport_requested(target_scene_path: String, target_spawn_point: StringName)

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_point: StringName

var _switch_requested := false
var _game_manager: Node


func _ready() -> void:
	_game_manager = get_node("/root/GameManager")
	body_entered.connect(_on_body_entered)


## 公开入口供测试和场景脚本复用；同一实例只接受一次切换请求。
func try_teleport(body: Node) -> bool:
	if _switch_requested or not body is Player:
		return false
	if target_scene_path.is_empty():
		push_error("TeleportRing: 未配置 target_scene_path。")
		return false
	var accepted: bool = _game_manager.call(
		"request_scene_change", target_scene_path, target_spawn_point)
	if accepted:
		_switch_requested = true
		teleport_requested.emit(target_scene_path, target_spawn_point)
	return accepted


func _on_body_entered(body: Node2D) -> void:
	try_teleport(body)
