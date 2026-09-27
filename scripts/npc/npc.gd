class_name Npc
extends CharacterBody2D
## 城镇 NPC：水平游荡，每 wander_interval 秒换向；对话期间停止移动。

signal interaction_started
signal interaction_finished

@export var speaker_name: String = "佟湘玉"
@export_multiline var dialog_text: String = "欢迎来到七侠镇。"
@export var dialog_duration: float = 3.0
@export var speed: float = 64.0
@export var wander_interval: float = 5.0

var direction := 1
var is_talking := false
var _wander_elapsed := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	play_animation(&"idle")


func _physics_process(delta: float) -> void:
	if is_talking:
		velocity = Vector2.ZERO
		return
	_wander_elapsed += delta
	if _wander_elapsed >= wander_interval:
		_wander_elapsed = 0.0
		direction *= -1
	velocity = Vector2(direction * speed, 0.0)
	animated_sprite.flip_h = direction < 0
	play_animation(&"walk_side")
	move_and_slide()


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
	_wander_elapsed = 0.0
	interaction_finished.emit()


func play_animation(animation: StringName) -> void:
	if animated_sprite.animation != animation:
		animated_sprite.play(animation)
