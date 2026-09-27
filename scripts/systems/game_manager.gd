extends Node
## 全局单例（Autoload 名：GameManager）。
##
## Phase 0 只提供三件最基础的事：查当前场景、记目标出生点、切场景。
## 玩法逻辑（传送判定、存档、进度）一律放在各自节点里，这里不做扩展。

## 场景切换开始时发出，供需要在切场景前保存状态的系统监听。
signal scene_change_started(scene_path: String, spawn_point: StringName)

const TOWN_SCENE := "res://scenes/levels/town.tscn"

## 目标出生点名。由新场景里的出生点消费，为空表示用场景默认位置。
var spawn_point_name: StringName = &""

var _scene_change_in_progress := false


## 当前场景根节点，尚未就绪时返回 null。
func get_current_scene() -> Node:
	return get_tree().current_scene


## 当前场景的资源路径，尚未就绪时返回空字符串。
func get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path


## 切换场景。spawn_point 会保留到新场景读取为止，用来决定玩家落点。
func request_scene_change(scene_path: String, spawn_point: StringName = &"") -> bool:
	if _scene_change_in_progress:
		return false
	if not ResourceLoader.exists(scene_path):
		push_error("GameManager: 场景不存在 -> %s" % scene_path)
		return false
	if scene_path == get_current_scene_path():
		return false
	spawn_point_name = spawn_point
	_scene_change_in_progress = true
	scene_change_started.emit(scene_path, spawn_point)
	_change_scene_deferred.call_deferred(scene_path)
	return true


func _change_scene_deferred(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	_scene_change_in_progress = false
	if error != OK:
		spawn_point_name = &""
		push_error("GameManager: 切换场景失败 -> %s" % scene_path)


## 取出并清空出生点标记，保证只被消费一次。
func consume_spawn_point() -> StringName:
	var point := spawn_point_name
	spawn_point_name = &""
	return point
