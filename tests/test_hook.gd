extends SceneTree
## Phase 4 无头测试：验证飞钩投射物与玩家抓取/拉拽状态。

const TOWN_SCENE := "res://scenes/levels/town.tscn"
const HOOK_SCENE := "res://scenes/effects/hook.tscn"
const EAVES_MASK := 1 << 3

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
	print("=== Phase 4 飞钩 / 钩爪无头测试 ===")
	var packed := load(TOWN_SCENE) as PackedScene
	_check("town.tscn 能加载", packed != null)
	if packed == null:
		_finish()
		return

	var world := packed.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame

	var player := world.get_node_or_null("World/Entities/Player") as Player
	var eaves := world.get_node_or_null("World/TownMap/Props/屋檐") as StaticBody2D
	var hook_packed := load(HOOK_SCENE) as PackedScene
	_check("Player 存在", player != null)
	_check("屋檐存在", eaves != null)
	_check("hook.tscn 能加载", hook_packed != null)
	_check("hook 输入动作存在", InputMap.has_action("hook"))
	_check("hook_fire 输入动作存在", InputMap.has_action("hook_fire"))
	_check("Player 注册 HookThrowState", player != null and player.get_node_or_null("StateMachine/HookThrowState") != null)
	_check("Player 注册 HookPullState", player != null and player.get_node_or_null("StateMachine/HookPullState") != null)
	if player == null or eaves == null or hook_packed == null:
		_finish()
		return

	_check("屋檐位于 eaves 物理层", (eaves.collision_layer & EAVES_MASK) != 0,
		"collision_layer=%d" % eaves.collision_layer)
	_check("屋檐仍保留 world 物理层", (eaves.collision_layer & 1) != 0,
		"collision_layer=%d" % eaves.collision_layer)

	var direct_attached := [false]
	var direct_point := [Vector2.ZERO]
	var direct_hook := hook_packed.instantiate()
	world.get_node("World").add_child(direct_hook)
	direct_hook.hook_attached.connect(func(point: Vector2) -> void:
		direct_attached[0] = true
		direct_point[0] = point)
	var eaves_center: Vector2 = eaves.global_position
	var direct_origin := eaves_center + Vector2(0.0, 120.0)
	direct_hook.launch(direct_origin, eaves_center, 400.0, 400.0)
	for i in 30:
		if direct_attached[0]:
			break
		await physics_frame
	_check("飞钩命中屋檐并发出 hook_attached", direct_attached[0])
	_check("命中点位于屋檐碰撞范围", direct_attached[0] and direct_point[0].distance_to(eaves_center) <= 40.0,
		"point=%s center=%s" % [direct_point[0], eaves_center])
	_check("命中后飞钩保持到收钩结束", is_instance_valid(direct_hook))
	if is_instance_valid(direct_hook):
		direct_hook.release()
	await process_frame
	_check("release 后飞钩回收", not is_instance_valid(direct_hook))

	var failed := [false]
	var failed_hook := hook_packed.instantiate()
	world.get_node("World").add_child(failed_hook)
	failed_hook.hook_failed.connect(func() -> void:
		failed[0] = true)
	failed_hook.launch(direct_origin, direct_origin + Vector2(0.0, 100.0), 400.0, 16.0)
	for i in 10:
		if failed[0]:
			break
		await physics_frame
	_check("达到射程上限后发出 hook_failed", failed[0])
	_check("未命中飞钩自动回收", not is_instance_valid(failed_hook))

	player.global_position = eaves_center + Vector2(0.0, -150.0)
	await physics_frame
	var anchor := eaves_center + Vector2(0.0, -26.88)
	_check("Idle 状态可以开始出钩", player.start_hook(eaves_center))
	var integration_point := [Vector2.ZERO]
	if player.active_hook != null:
		player.active_hook.hook_attached.connect(func(point: Vector2) -> void:
			integration_point[0] = point)
	_check("出钩期间不能重复发射", not player.start_hook(eaves_center))
	_check("出钩后进入 HookThrowState", player.state_machine.current_state.name == &"HookThrowState")

	var saw_pull := false
	var observed_anchor := Vector2.ZERO
	var locked_velocity := true
	for i in 120:
		if player.state_machine.current_state.name == &"HookPullState":
			if not saw_pull:
				observed_anchor = player.hook_anchor
			saw_pull = true
			locked_velocity = locked_velocity and player.velocity == Vector2.ZERO
		if saw_pull and player.state_machine.current_state.name == &"IdleState":
			break
		await physics_frame
	_check("命中后进入 HookPullState", saw_pull)
	_check("拉拽期间普通移动速度保持为零", locked_velocity)
	_check("拉拽结束回到 IdleState", player.state_machine.current_state.name == &"IdleState",
		"state=%s observed_anchor=%s hit=%s" % [player.state_machine.current_state.name, observed_anchor, integration_point[0]])
	_check("玩家到达命中点", player.global_position.is_equal_approx(anchor),
		"player=%s expected=%s observed=%s" % [player.global_position, anchor, observed_anchor])
	_check("拉拽结束后清理 active_hook", player.active_hook == null)

	_finish()


func _finish() -> void:
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
