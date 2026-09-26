extends State
## 移动：有输入时按 walk_speed 位移。
##
## 双击加速（sprint_multiplier / sprint_window）留到 Phase 1，
## 数值已经在 PlayerStatsData 里备好，这里先不实现。


func physics_update(_delta: float) -> void:
	if player.input_vector == Vector2.ZERO:
		# 先清速度再切状态，否则这一帧还会按旧速度滑出去 1 px。
		player.velocity = Vector2.ZERO
		state_machine.change_state(&"IdleState")
		return
	player.velocity = player.input_vector * player.stats.walk_speed