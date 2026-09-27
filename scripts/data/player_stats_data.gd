class_name PlayerStatsData
extends Resource
## 玩家数值。
##
## Unity 原值（rolemove.speed = 0.3 / runSpeed = 1|2）是"格每帧"体系，
## Godot 用像素每秒，因此这里按 32 px 瓦片重新给了合理值，不机械照搬。
##
## 移动相关的三个值集中放这里，代码里不再出现魔法数字。

@export var walk_speed: float = 90.0
@export var run_speed: float = 180.0
@export var double_tap_window: float = 0.5
@export var hook_speed: float = 400.0
@export var hook_range: float = 320.0
@export var body_size: Vector2 = Vector2(24, 32)
