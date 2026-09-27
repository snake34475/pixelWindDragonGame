extends State
## 出钩：创建飞钩并等待命中或失败，期间玩家不可移动。

const HOOK_SCENE := preload("res://scenes/effects/hook.tscn")

var _hook: Hook


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_animation("idle")
	_hook = HOOK_SCENE.instantiate() as Hook
	player.get_parent().add_child(_hook)
	player.active_hook = _hook
	_hook.hook_attached.connect(_on_hook_attached)
	_hook.hook_failed.connect(_on_hook_failed)
	_hook.launch(
		player.global_position,
		player.take_pending_hook_target(),
		player.stats.hook_speed,
		player.stats.hook_range)


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO


func exit() -> void:
	if is_instance_valid(_hook) and _hook.is_active():
		_hook.cancel()


func _on_hook_attached(point: Vector2) -> void:
	player.hook_anchor = point
	state_machine.change_state(&"HookPullState")


func _on_hook_failed() -> void:
	player.active_hook = null
	state_machine.change_state(&"IdleState")
