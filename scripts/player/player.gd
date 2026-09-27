class_name Player
extends CharacterBody2D
## 玩家。
##
## 移动、朝向、动画和钩爪状态入口。

const FACING_UP := Vector2.UP
const FACING_DOWN := Vector2.DOWN
const FACING_LEFT := Vector2.LEFT
const FACING_RIGHT := Vector2.RIGHT

## 素材只有 idle_down / walk_down / walk_up / walk_side / run_side 五组，
## 向上、左右待机与向上、向下奔跑没有独立素材，回退到最接近的可用动画。
## 纵向奔跑暂时复用 walk_up / walk_down 帧，但移动速度仍由 is_sprinting 决定。
## 补到新素材时，删掉对应条目并往 SpriteFrames 里加动画即可，逻辑不用改。
const ANIMATION_FALLBACK := {
	&"idle_up": &"idle_down",
	&"idle_side": &"idle_down",
	&"run_down": &"walk_down",
	&"run_up": &"walk_up",
}

@export var stats: PlayerStatsData

## 本帧输入，已归一化（斜向不会更快）。
var input_vector: Vector2 = Vector2.ZERO

## 最近一次非零朝向，只会是上下左右四者之一，动画/交互都读它。
var facing: Vector2 = Vector2.DOWN

## 双击同方向后在 double_tap_window 内置位，由 MoveState 消费。
var is_sprinting: bool = false

## 当前飞钩和拉拽目标；钩爪状态通过这两个节点外字段交接。
var active_hook: Hook
var hook_anchor: Vector2 = Vector2.ZERO
var active_npc: Npc
var input_locked := false
var is_swimming := false
var _water_zone_count := 0
var _normal_modulate := Color.WHITE

var _last_tap_direction: Vector2 = Vector2.ZERO
var _last_tap_time: float = -1.0
var _pending_hook_target: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	if stats == null:
		push_warning("Player: 未指定 PlayerStatsData，回退到默认数值。")
		stats = PlayerStatsData.new()
	_normal_modulate = animated_sprite.modulate
	state_machine.start()


func _physics_process(delta: float) -> void:
	if input_locked:
		input_vector = Vector2.ZERO
	else:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		_update_facing()
		_update_sprint()
	_try_start_hook()
	state_machine.physics_update(delta)
	if velocity != Vector2.ZERO:
		move_and_slide()


## 按住 E 后点击左键，朝鼠标世界坐标出钩。
func start_hook(target_global_position: Vector2) -> bool:
	if not can_start_hook():
		return false
	_pending_hook_target = target_global_position
	state_machine.change_state(&"HookThrowState")
	return true


## Idle/Move 可出钩；其他状态或已有飞钩时拒绝重复发射。
func can_start_hook() -> bool:
	if active_hook != null or state_machine.current_state == null:
		return false
	return state_machine.current_state.name in [&"IdleState", &"MoveState"]


func take_pending_hook_target() -> Vector2:
	return _pending_hook_target


## 进入 NPC 对话状态；只有 Idle/Move 且没有其他交互时可以开始。
func start_interaction(npc: Npc) -> bool:
	if not can_start_interaction():
		return false
	active_npc = npc
	state_machine.change_state(&"InteractState")
	return true


func can_start_interaction() -> bool:
	if input_locked or active_hook != null or active_npc != null or state_machine.current_state == null:
		return false
	return state_machine.current_state.name in [&"IdleState", &"MoveState"]


## 对话关闭后恢复普通状态，由交互协调器调用。
func finish_interaction() -> void:
	active_npc = null
	if state_machine.current_state != null and state_machine.current_state.name == &"InteractState":
		state_machine.change_state(&"IdleState")


## 支持多个水域重叠；只有全部离开后才恢复正常表现。
func enter_water() -> void:
	_water_zone_count += 1
	_apply_water_state()


func exit_water() -> void:
	_water_zone_count = maxi(_water_zone_count - 1, 0)
	_apply_water_state()


func water_zone_count() -> int:
	return _water_zone_count


func _apply_water_state() -> void:
	is_swimming = _water_zone_count > 0
	animated_sprite.modulate = Color(0.72, 0.86, 1.0, 0.75) if is_swimming else _normal_modulate


## 当前移动速度：加速中走 run_speed，否则 walk_speed。
func current_speed() -> float:
	return stats.run_speed if is_sprinting else stats.walk_speed


## 按 "前缀_方向后缀" 播放动画。同名动画不重启，避免逐帧 restart。
## 目标动画不存在时查 ANIMATION_FALLBACK，仍然没有就退回 idle_down。
func play_animation(prefix: String) -> void:
	var target: StringName = StringName("%s_%s" % [prefix, facing_suffix()])
	if not animated_sprite.sprite_frames.has_animation(target):
		target = ANIMATION_FALLBACK.get(target, &"idle_down")
	if animated_sprite.animation != target:
		animated_sprite.play(target)


## 当前朝向对应的动画后缀：up / down / side。
func facing_suffix() -> String:
	if absf(facing.x) > absf(facing.y):
		return "side"
	return "up" if facing.y < 0.0 else "down"


## 把 input_vector 收敛到四方向，并同步左右翻转。
func _update_facing() -> void:
	if input_vector == Vector2.ZERO:
		return
	if absf(input_vector.x) > absf(input_vector.y):
		facing = FACING_LEFT if input_vector.x < 0.0 else FACING_RIGHT
	else:
		facing = FACING_UP if input_vector.y < 0.0 else FACING_DOWN
	# 只在水平朝向时翻转，与 Unity 原实现一致（上下行走保持上一次的左右朝向）。
	if facing.x != 0.0:
		animated_sprite.flip_h = facing.x < 0.0


## 双击同一方向：窗口内再次按下则进入奔跑。
## 奔跑期间改变方向会保持奔跑，只有输入完全归零才退出。
func _update_sprint() -> void:
	if input_vector == Vector2.ZERO:
		is_sprinting = false
		return
	var tapped := _just_pressed_direction()
	if tapped == Vector2.ZERO or is_sprinting:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	is_sprinting = tapped == _last_tap_direction and now - _last_tap_time <= stats.double_tap_window
	_last_tap_direction = tapped
	_last_tap_time = now


func _try_start_hook() -> void:
	if Input.is_action_pressed("hook") and Input.is_action_just_pressed("hook_fire"):
		start_hook(get_global_mouse_position())


## 本帧刚按下的方向键，多个同时按下时按 上/下/左/右 顺序取第一个。
func _just_pressed_direction() -> Vector2:
	if Input.is_action_just_pressed("move_up"):
		return FACING_UP
	if Input.is_action_just_pressed("move_down"):
		return FACING_DOWN
	if Input.is_action_just_pressed("move_left"):
		return FACING_LEFT
	if Input.is_action_just_pressed("move_right"):
		return FACING_RIGHT
	return Vector2.ZERO
