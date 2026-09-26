extends State
## 移动：按 walk/run 速度位移，并播放对应方向的动画。
##
## 加速不单独开状态：双击同方向只是把速度与动画名从 walk_ 换成 run_，
## 移动逻辑完全相同，用 player.is_sprinting 区分即可。


func enter() -> void:
	_apply_movement()


func physics_update(_delta: float) -> void:
	if player.input_vector == Vector2.ZERO:
		# 先清速度再切状态，否则这一帧还会按旧速度滑出去 1 px。
		player.velocity = Vector2.ZERO
		state_machine.change_state(&"IdleState")
		return
	_apply_movement()


func _apply_movement() -> void:
	player.velocity = player.input_vector * player.current_speed()
	player.play_animation("run" if player.is_sprinting else "walk")