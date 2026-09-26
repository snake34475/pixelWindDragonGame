extends State
## 待机：没有输入时保持静止。


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	if player.input_vector != Vector2.ZERO:
		state_machine.change_state(&"MoveState")