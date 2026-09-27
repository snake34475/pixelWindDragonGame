class_name SpawnPointManager
extends Node2D
## 消费 GameManager 的一次性出生点名，并把玩家移动到对应 Marker2D。

@export_node_path("Player") var player_path: NodePath

@onready var player: Player = get_node(player_path) as Player
@onready var game_manager: Node = get_node("/root/GameManager")


func _ready() -> void:
	call_deferred("_apply_requested_spawn_point")


func _apply_requested_spawn_point() -> void:
	var requested: StringName = game_manager.call("consume_spawn_point")
	if requested == &"":
		return
	if player == null:
		push_error("SpawnPointManager: Player 未配置。")
		return
	var marker := find_child(String(requested), true, false) as Marker2D
	if marker == null:
		push_warning("SpawnPointManager: 未找到出生点 -> %s" % requested)
		return
	player.velocity = Vector2.ZERO
	player.global_position = marker.global_position
