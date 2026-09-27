extends SceneTree
## Phase 6 无头测试：验证 NPC 游荡、C 交互和对话框锁定。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const NPC_LAYER := 1 << 2

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s%s" % [label, (" -> " + detail) if detail != "" else ""])


func _run() -> void:
	print("=== Phase 6 NPC / 对话框无头测试 ===")
	var packed := load(TOWN_SCENE) as PackedScene
	_check("town.tscn 能加载", packed != null)
	if packed == null:
		_finish()
		return
	var town := packed.instantiate()
	root.add_child(town)
	await physics_frame
	await physics_frame

	var player := town.get_node_or_null("World/Entities/Player") as Player
	var npc := town.get_node_or_null("World/Entities/Npc") as Npc
	var interactor := town.get_node_or_null("World/NpcInteractor") as NpcInteractor
	var dialog := town.get_node_or_null("UI/NpcDialog") as NpcDialog
	_check("Player 存在", player != null)
	_check("Npc 存在", npc != null)
	_check("NpcInteractor 存在", interactor != null)
	_check("NpcDialog 存在", dialog != null)
	_check("interact 输入动作存在", InputMap.has_action("interact"))
	if player == null or npc == null or interactor == null or dialog == null:
		_finish()
		return

	var sprite := npc.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check("NPC 位于 npc 物理层", (npc.collision_layer & NPC_LAYER) != 0,
		"layer=%d" % npc.collision_layer)
	_check("NPC idle 动画为 2 帧", sprite.sprite_frames.get_frame_count(&"idle") == 2)
	_check("NPC walk_side 动画为 4 帧", sprite.sprite_frames.get_frame_count(&"walk_side") == 4)

	npc.collision_mask = 0
	npc.global_position = Vector2(80, 0)
	player.global_position = Vector2.ZERO
	var fixed_position := npc.global_position
	for i in 10:
		await physics_frame
	_check("NPC 固定站位不移动", npc.global_position.is_equal_approx(fixed_position),
		"before=%s after=%s" % [fixed_position, npc.global_position])
	_check("玩家在左侧时 NPC 朝左", sprite.flip_h == false)
	player.global_position = Vector2(160, 0)
	await physics_frame
	await physics_frame
	_check("玩家在右侧时 NPC 朝右", sprite.flip_h == true)
	player.global_position = Vector2.ZERO
	await physics_frame
	npc.dialog_duration = 0.15
	player.facing = Vector2.RIGHT
	player.state_machine.change_state(&"IdleState")
	await physics_frame
	await physics_frame

	_check("玩家朝 NPC 按交互可以命中", interactor.try_interact())
	_check("NPC 进入对话状态", npc.is_talking)
	_check("NPC 对话时播放 idle", sprite.animation == &"idle")
	_check("玩家进入 InteractState", player.state_machine.current_state.name == &"InteractState")
	_check("对话期间玩家输入锁定", player.input_locked)
	_check("对话框已显示", dialog.visible)
	_check("对话框显示说话人", dialog.speaker_label.text == npc.speaker_name,
		dialog.speaker_label.text)
	_check("对话框显示文本", dialog.text_label.text == npc.dialog_text,
		dialog.text_label.text)

	var locked_position := player.global_position
	Input.action_press("move_right")
	for i in 3:
		await physics_frame
	Input.action_release("move_right")
	_check("对话期间玩家不能移动", player.global_position.is_equal_approx(locked_position),
		"before=%s after=%s" % [locked_position, player.global_position])

	for i in 20:
		if not dialog.visible:
			break
		await physics_frame
	_check("对话框到时自动关闭", not dialog.visible)
	_check("对话结束后 NPC 解除对话且保持固定", not npc.is_talking
		and npc.global_position.is_equal_approx(fixed_position))
	_check("对话结束后玩家恢复 IdleState", player.state_machine.current_state.name == &"IdleState")
	_check("对话结束后解除输入锁定", not player.input_locked)

	_finish()


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
