class_name TileDestructor
extends Node
## Phase 3：处理玩家前方石障的破坏。
##
## 当前 TownMap 的 Obstacles 图层仅包含可破坏石障；不要通过贴图 atlas
## 坐标判断类型，以免地图重新生成后逻辑与资源布局耦合。

signal tile_destroyed(cell: Vector2i)

const STONE_BREAK_SCENE := preload("res://scenes/effects/stone_break.tscn")

@export_node_path("Player") var player_path: NodePath
@export_node_path("TileMapLayer") var obstacles_path: NodePath

@onready var player: Player = get_node(player_path) as Player
@onready var obstacles: TileMapLayer = get_node(obstacles_path) as TileMapLayer


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("blast_tile"):
		try_destroy_in_front()


## 尝试移除玩家当前朝向前一格的石障；成功时返回 true。
## 公开该入口，使表现层或测试不必模拟输入来复用核心规则。
func try_destroy_in_front() -> bool:
	if player == null or obstacles == null:
		push_error("TileDestructor: Player 或 Obstacles 未配置。")
		return false

	var cell := target_cell()
	if obstacles.get_cell_source_id(cell) == -1:
		return false

	obstacles.erase_cell(cell)
	_spawn_break_effect(cell)
	tile_destroyed.emit(cell)
	return true


## TileMapLayer 的格坐标由其本地坐标推导；先转回地图局部空间，避免未来
## TownMap 移动或缩放时使用世界坐标导致目标偏移。
func target_cell() -> Vector2i:
	var tile_size := Vector2(obstacles.tile_set.tile_size)
	var target_global := player.global_position + player.facing * tile_size
	return obstacles.local_to_map(obstacles.to_local(target_global))


func _spawn_break_effect(cell: Vector2i) -> void:
	var effect := STONE_BREAK_SCENE.instantiate() as Node2D
	obstacles.get_parent().add_child(effect)
	effect.global_position = obstacles.to_global(obstacles.map_to_local(cell))
