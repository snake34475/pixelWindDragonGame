class_name State
extends Node
## 状态基类。子类按需覆写 enter / exit / physics_update。

var state_machine: StateMachine
var player: Player


## 进入本状态时调用一次。
func enter() -> void:
	pass


## 离开本状态时调用一次。
func exit() -> void:
	pass


## 每个物理帧调用，由状态负责写入 player.velocity。
func physics_update(_delta: float) -> void:
	pass