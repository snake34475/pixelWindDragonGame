extends Node2D
## 碎石动画播完即回收；逻辑层不需要等待它完成。

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_sprite.animation_finished.connect(queue_free)
	animated_sprite.play(&"break")
