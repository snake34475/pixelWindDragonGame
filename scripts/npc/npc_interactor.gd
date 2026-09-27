class_name NpcInteractor
extends Node
## 读取 C 输入，用射线寻找玩家前方的 NPC，并协调玩家状态与对话框。

@export_node_path("Player") var player_path: NodePath
@export_node_path("NpcDialog") var dialog_path: NodePath
@export var interaction_range: float = 160.0
@export_flags_2d_physics var npc_mask: int = 4

@onready var player: Player = get_node(player_path) as Player
@onready var dialog: NpcDialog = get_node(dialog_path) as NpcDialog

var active_npc: Npc


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") and player.can_start_interaction():
		try_interact()


## 公开入口供测试和非输入场景复用。
func try_interact() -> bool:
	if not player.can_start_interaction() or dialog == null:
		return false
	var origin := player.global_position + Vector2(0.0, -12.0)
	var query := PhysicsRayQueryParameters2D.create(
		origin, origin + player.facing * interaction_range, npc_mask)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	var npc := result.get("collider") as Npc
	if npc == null or not npc.start_interaction():
		return false
	if not player.start_interaction(npc):
		npc.finish_interaction()
		return false
	active_npc = npc
	dialog.show_dialog(npc.speaker_name, npc.dialog_text, npc.dialog_duration)
	dialog.dialog_closed.connect(_on_dialog_closed, CONNECT_ONE_SHOT)
	return true


func _on_dialog_closed() -> void:
	if is_instance_valid(active_npc):
		active_npc.finish_interaction()
	active_npc = null
	player.finish_interaction()
