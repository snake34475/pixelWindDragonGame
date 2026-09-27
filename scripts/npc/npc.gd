class_name Npc
extends CharacterBody2D
## 城镇 NPC：固定站位并水平朝向玩家；对话期间保持静止。

signal interaction_started
signal interaction_finished

@export var speaker_name: String = "佟湘玉"
@export_multiline var dialog_text: String = "欢迎来到七侠镇。"
@export var dialog_duration: float = 3.0
@export_node_path("Player") var player_path: NodePath = NodePath("../Player")

## 1 = 朝右，-1 = 朝左；只用于翻转精灵，不产生位移。
var facing_direction := 1
var is_talking := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _player: Player


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	play_animation(&"idle")
	_update_facing()


func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO
	_update_facing()


func start_interaction() -> bool:
	if is_talking:
		return false
	is_talking = true
	velocity = Vector2.ZERO
	play_animation(&"idle")
	interaction_started.emit()
	return true


func finish_interaction() -> void:
	if not is_talking:
		return
	is_talking = false
	interaction_finished.emit()


func play_animation(animation: StringName) -> void:
	if animated_sprite.animation != animation:
		animated_sprite.play(animation)


func _update_facing() -> void:
	if not is_instance_valid(_player):
		return
	var offset_x := _player.global_position.x - global_position.x
	if absf(offset_x) < 1.0:
		return
	facing_direction = 1 if offset_x > 0.0 else -1
	# 佟湘玉精灵原画朝向左侧；玩家在右侧时水平翻转。
	animated_sprite.flip_h = facing_direction > 0
