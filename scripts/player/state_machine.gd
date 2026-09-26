class_name StateMachine
extends Node
## 轻量状态机：每个状态是本节点的子节点，子节点名即状态名。

## 启动状态名，需与某个子节点名一致。
@export var initial_state: StringName = &"IdleState"

var current_state: State

var _states: Dictionary = {}


func _ready() -> void:
	var player := get_parent() as Player
	for child in get_children():
		if child is State:
			var state := child as State
			state.state_machine = self
			state.player = player
			_states[state.name] = state


## 由 Player._ready() 调用：子节点 _ready 早于父节点，等 Player 的
## @onready 引用就绪后再启动，避免状态里访问到 null。
func start() -> void:
	change_state(initial_state)


func change_state(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: 未注册的状态 -> %s" % state_name)
		return
	if current_state != null:
		current_state.exit()
	current_state = _states[state_name]
	current_state.enter()


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)