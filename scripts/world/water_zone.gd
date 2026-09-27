class_name WaterZone
extends Area2D
## 水域只负责检测玩家进出，实际表现由 Player 统一管理。

signal player_entered(player: Player)
signal player_exited(player: Player)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.enter_water()
	player_entered.emit(player)


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.exit_water()
	player_exited.emit(player)
