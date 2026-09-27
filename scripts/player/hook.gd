class_name Hook
extends Node2D
## 飞钩投射物。只负责飞行、命中检测和结果通知，不直接操作玩家。

signal hook_attached(point: Vector2)
signal hook_failed

@onready var ray_cast: RayCast2D = $RayCast2D
@onready var chain: Line2D = $Chain

var _direction := Vector2.RIGHT
var _tail_position := Vector2.ZERO
var _speed := 0.0
var _remaining_distance := 0.0
var _active := false
var _finished := false


func _ready() -> void:
	visible = false
	ray_cast.enabled = false


## 从 origin 朝 target 发射，最多飞行 max_range 像素。
func launch(origin: Vector2, target: Vector2, speed: float, max_range: float) -> void:
	global_position = origin
	_tail_position = origin
	var offset := target - origin
	var distance := offset.length()
	_direction = offset / distance if distance > 0.0 else Vector2.RIGHT
	_speed = maxf(speed, 1.0)
	_remaining_distance = minf(distance, maxf(max_range, 0.0))
	_active = distance > 0.0 and _remaining_distance > 0.0
	rotation = _direction.angle()
	visible = _active
	ray_cast.enabled = _active
	_update_chain()
	if not _active:
		call_deferred("_fail")


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var step := minf(_speed * delta, _remaining_distance)
	# 根节点已旋转到飞行方向，射线目标必须保持局部 +X。
	ray_cast.target_position = Vector2(step, 0.0)
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		global_position = ray_cast.get_collision_point()
		_update_chain()
		_finished = true
		_active = false
		ray_cast.enabled = false
		hook_attached.emit(global_position)
		return
	global_position += _direction * step
	_remaining_distance -= step
	_update_chain()
	if _remaining_distance <= 0.001:
		_fail()


func is_active() -> bool:
	return _active


## 拉拽期间由玩家状态更新链条起点。
func set_tail_position(global_tail: Vector2) -> void:
	_tail_position = global_tail
	_update_chain()


## 正常到达后回收。命中信号已发出，不再产生失败信号。
func release() -> void:
	_finished = true
	_active = false
	queue_free()


## 状态中断时回收，不产生信号。
func cancel() -> void:
	_finished = true
	_active = false
	queue_free()


func _update_chain() -> void:
	chain.points = PackedVector2Array([to_local(_tail_position), Vector2.ZERO])


func _fail() -> void:
	if _finished:
		return
	_finished = true
	_active = false
	ray_cast.enabled = false
	hook_failed.emit()
	queue_free()
