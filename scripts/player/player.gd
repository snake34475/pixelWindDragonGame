class_name Player
extends CharacterBody2D
## 玩家骨架。
##
## Phase 0 只做三件事：读输入、记录朝向、交给状态机决定速度。
## 钩爪 / 炸石 / NPC 交互 / 水域 / 传送 / 战斗都还没进来。

@export var stats: PlayerStatsData

## 本帧输入，已归一化（斜向不会更快）。
var input_vector: Vector2 = Vector2.ZERO

## 最近一次非零朝向。交互射线、钩爪方向、动画选帧都要用。
var facing: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	if stats == null:
		push_warning("Player: 未指定 PlayerStatsData，回退到默认数值。")
		stats = PlayerStatsData.new()


func _physics_process(delta: float) -> void:
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		facing = input_vector
		sprite.flip_h = facing.x < 0.0
	state_machine.physics_update(delta)
	move_and_slide()