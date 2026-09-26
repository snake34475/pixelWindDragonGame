extends State
## 待机：没有输入时保持静止，播 idle_xxx。


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_animation("idle")


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	if player.input_vector != Vector2.ZERO:
		state_machine.change_state(&"MoveState")