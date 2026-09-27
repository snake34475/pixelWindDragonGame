extends State
## 收钩：按固定速度拉向命中点，期间忽略普通移动输入。

var _hook: Hook
var _anchor := Vector2.ZERO


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_animation("idle")
	_hook = player.active_hook
	_anchor = player.hook_anchor
	if not is_instance_valid(_hook):
		_finish()


func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	if not is_instance_valid(_hook):
		_finish()
		return
	var offset := _anchor - player.global_position
	var distance := offset.length()
	var step := player.stats.hook_speed * delta
	if distance <= step:
		player.global_position = _anchor
		_finish()
		return
	player.global_position += offset / distance * step
	_hook.set_tail_position(player.global_position)


func exit() -> void:
	if is_instance_valid(_hook):
		_hook.release()
	if player.active_hook == _hook:
		player.active_hook = null
	player.hook_anchor = Vector2.ZERO


func _finish() -> void:
	state_machine.change_state(&"IdleState")
