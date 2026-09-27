extends State
## 对话期间锁定玩家移动与输入。


func enter() -> void:
	player.input_locked = true
	player.velocity = Vector2.ZERO
	player.play_animation("idle")


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO


func exit() -> void:
	player.input_locked = false
