extends SceneTree
## Phase 1 无头测试：验证玩家动画资源是否加载正确，以及
## 四方向移动 / 停止 / 双击奔跑 / 左右 flip 是否切到正确动画。
##
## 运行：
##   godot --headless --path . --script res://tests/test_player_animation.gd
## 退出码 0 = 全部通过，1 = 有失败项。

const TOWN_SCENE := "res://scenes/levels/town.tscn"

## 动画名 -> 期望帧数
const EXPECTED_ANIMATIONS := {
	&"idle_down": 2,
	&"walk_down": 4,
	&"walk_up": 3,
	&"walk_side": 4,
	&"run_side": 6,
}

## 动画名 -> 期望 FPS（与 player_sprite_frames.tres 的 speed 一致）
const EXPECTED_SPEEDS := {
	&"idle_down": 4.0,
	&"walk_down": 8.0,
	&"walk_up": 6.0,
	&"walk_side": 8.0,
	&"run_side": 12.0,
}

const EXPECTED_FRAME_SIZE := Vector2i(94, 81)
const EXPECTED_WALK_SPEED := 90.0
const EXPECTED_RUN_SPEED := 180.0

var _checks: int = 0
var _failures: int = 0
var _player: Player
var _sprite: AnimatedSprite2D


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s%s" % [label, ("  -> " + detail) if detail != "" else ""])


func _anim() -> StringName:
	return _sprite.animation


func _state() -> StringName:
	return _player.state_machine.current_state.name


## 按住某个方向键若干物理帧，返回后仍保持按住。
func _hold(action: String, frames: int = 3) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame


## 轻点一次。无头环境下 Input.action_press 需要至少 1 个物理帧才会被
## is_action_just_pressed 观察到，所以按住 3 帧再松开，保证点击被记录。
## release = false 时保持按住，供调用方检查奔跑状态。
func _tap(action: String, release: bool = true) -> void:
	Input.action_press(action)
	for i in 3:
		await physics_frame
	if release:
		Input.action_release(action)
		await physics_frame


func _release_all() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)
	await physics_frame


func _run() -> void:
	print("=== Phase 1 玩家动画无头测试 ===")

	# ---------- 1. 场景与资源 ----------
	print("\n[1] 场景加载与资源")
	var town_packed := load(TOWN_SCENE)
	_check("town.tscn 能加载", town_packed != null)
	var town: Node = town_packed.instantiate()
	root.add_child(town)
	# _initialize() 里 add_child 时场景树尚未开始，_ready 会被推迟到第一帧，
	# 先等一帧让 @onready 引用和 StateMachine.start() 生效。
	await physics_frame
	await physics_frame

	_player = town.get_node_or_null("World/Entities/Player") as Player
	_check("Player 能实例化", _player != null)
	if _player == null:
		_finish()
		return

	_sprite = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check("AnimatedSprite2D 存在", _sprite != null)
	_check("CollisionShape2D 存在", _player.get_node_or_null("CollisionShape2D") != null)
	_check("Camera2D 存在", _player.get_node_or_null("Camera2D") != null)
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	_check("Camera2D 缩放 = 2/3", camera != null
		and camera.zoom.is_equal_approx(Vector2(0.6666667, 0.6666667)),
		"实际 %s" % (camera.zoom if camera != null else Vector2.ZERO))
	_check("StateMachine 存在", _player.state_machine != null)
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var window_width := int(ProjectSettings.get_setting("display/window/size/window_width_override"))
	var window_height := int(ProjectSettings.get_setting("display/window/size/window_height_override"))
	_check("内部视口 = 960x540", viewport_width == 960 and viewport_height == 540,
		"实际 %dx%d" % [viewport_width, viewport_height])
	_check("窗口覆盖尺寸 = 1920x1080", window_width == 1920 and window_height == 1080,
		"实际 %dx%d" % [window_width, window_height])
	_check("整数缩放 = 2x", window_width / viewport_width == 2 and window_height / viewport_height == 2,
		"实际 %.2fx" % (float(window_width) / viewport_width))
	if _sprite == null:
		_finish()
		return

	var frames: SpriteFrames = _sprite.sprite_frames
	_check("SpriteFrames 已加载", frames != null)
	if frames == null:
		_finish()
		return

	for anim in EXPECTED_ANIMATIONS:
		var want: int = EXPECTED_ANIMATIONS[anim]
		var ok := frames.has_animation(anim)
		_check("动画 %s 存在" % anim, ok)
		if ok:
			_check("  %s 帧数 = %d" % [anim, want], frames.get_frame_count(anim) == want,
				"实际 %d" % frames.get_frame_count(anim))
			var spd := frames.get_animation_speed(anim)
			_check("  %s FPS = %.0f" % [anim, EXPECTED_SPEEDS[anim]],
				is_equal_approx(spd, EXPECTED_SPEEDS[anim]), "实际 %.1f" % spd)
			var size_ok := true
			for i in frames.get_frame_count(anim):
				if frames.get_frame_texture(anim, i).get_size() != Vector2(EXPECTED_FRAME_SIZE):
					size_ok = false
			_check("  %s 每帧尺寸统一为 %s" % [anim, EXPECTED_FRAME_SIZE], size_ok)

	_check("没有多余动画（只建了 5 个）", frames.get_animation_names().size() == 5,
		"实际 %s" % str(frames.get_animation_names()))

	_check("初始朝向 = 下", _player.facing == Vector2.DOWN)
	_check("初始动画 = idle_down", _anim() == &"idle_down", "实际 %s" % _anim())
	_check("初始状态 = IdleState", _state() == &"IdleState", "实际 %s" % _state())
	_check("walk_speed = 90", is_equal_approx(_player.stats.walk_speed, EXPECTED_WALK_SPEED),
		"实际 %.1f" % _player.stats.walk_speed)
	_check("run_speed = 180", is_equal_approx(_player.stats.run_speed, EXPECTED_RUN_SPEED),
		"实际 %.1f" % _player.stats.run_speed)

	# ---------- 2. 四方向移动 ----------
	print("\n[2] 四方向移动")
	await _hold("move_right")
	_check("按 D -> facing = 右", _player.facing == Vector2.RIGHT, "实际 %s" % _player.facing)
	_check("按 D -> 状态 = MoveState", _state() == &"MoveState", "实际 %s" % _state())
	_check("按 D -> 动画 = walk_side", _anim() == &"walk_side", "实际 %s" % _anim())
	_check("按 D -> flip_h = false（朝右）", _sprite.flip_h == false)
	await _release_all()

	await _hold("move_left")
	_check("按 A -> facing = 左", _player.facing == Vector2.LEFT, "实际 %s" % _player.facing)
	_check("按 A -> 动画 = walk_side", _anim() == &"walk_side", "实际 %s" % _anim())
	_check("按 A -> flip_h = true（朝左）", _sprite.flip_h == true)
	await _release_all()

	await _hold("move_up")
	_check("按 W -> facing = 上", _player.facing == Vector2.UP, "实际 %s" % _player.facing)
	_check("按 W -> 动画 = walk_up", _anim() == &"walk_up", "实际 %s" % _anim())
	await _release_all()

	await _hold("move_down")
	_check("按 S -> facing = 下", _player.facing == Vector2.DOWN, "实际 %s" % _player.facing)
	_check("按 S -> 动画 = walk_down", _anim() == &"walk_down", "实际 %s" % _anim())
	await _release_all()

	# ---------- 3. 停止 ----------
	print("\n[3] 停止移动")
	await _hold("move_down")
	_check("停止前 状态 = MoveState", _state() == &"MoveState", "实际 %s" % _state())
	await _release_all()
	for i in 3:
		await physics_frame
	_check("松开后 状态 = IdleState", _state() == &"IdleState", "实际 %s" % _state())
	_check("松开后 动画 = idle_down", _anim() == &"idle_down", "实际 %s" % _anim())
	_check("松开后 速度归零", _player.velocity == Vector2.ZERO, "实际 %s" % _player.velocity)

	# ---------- 4. 双击奔跑 ----------
	print("\n[4] 双击奔跑")
	await _test_sprint("move_right", "右", Vector2.RIGHT)
	await _test_sprint("move_left", "左", Vector2.LEFT)
	await _test_sprint("move_up", "上", Vector2.UP)
	await _test_sprint("move_down", "下", Vector2.DOWN)
	await _test_sprint_keeps_direction_change()

	# ---------- 5. 动画不逐帧重启 ----------
	print("\n[5] 动画切换只在变化时发生")
	await _hold("move_down", 5)
	var frame_before := _sprite.frame
	var anim_before := _anim()
	for i in 5:
		await physics_frame
	_check("持续按 S 时动画名不变", _anim() == anim_before, "实际 %s" % _anim())
	_check("持续按 S 时帧在推进（动画确实在播）", _sprite.frame != frame_before or _sprite.is_playing(),
		"frame %d -> %d" % [frame_before, _sprite.frame])
	await _release_all()

	_finish()


## 双击同方向 -> is_sprinting = true。
## 横向使用 run_side；纵向没有独立奔跑素材，回退到 walk_up / walk_down。
## 第二次轻点保持按住，否则松开后 is_sprinting 会立刻被清零，检查不到奔跑状态。
func _test_sprint(action: String, label: String, expected_facing: Vector2) -> void:
	await _tap(action)
	await _tap(action, false)
	_check("双击%s -> facing = %s" % [label, expected_facing], _player.facing == expected_facing,
		"实际 %s" % _player.facing)
	_check("双击%s -> is_sprinting = true" % label, _player.is_sprinting == true)
	var expected_animation: StringName = &"run_side"
	if expected_facing == Vector2.UP:
		expected_animation = &"walk_up"
	elif expected_facing == Vector2.DOWN:
		expected_animation = &"walk_down"
	_check("双击%s -> 动画 = %s" % [label, expected_animation], _anim() == expected_animation,
		"实际 %s" % _anim())
	_check("双击%s -> 速度 = run_speed" % label,
		is_equal_approx(_player.current_speed(), _player.stats.run_speed),
		"实际 %.1f" % _player.current_speed())
	await _release_all()
	for i in 3:
		await physics_frame
	_check("松开%s -> is_sprinting = false" % label, _player.is_sprinting == false)
	_check("松开%s -> 回到 idle_down" % label, _anim() == &"idle_down", "实际 %s" % _anim())


## 横向奔跑中按 W 改变方向，仍应保持奔跑和 run_speed，纵向动画回退到 walk_up。
func _test_sprint_keeps_direction_change() -> void:
	await _tap("move_right")
	await _tap("move_right", false)
	Input.action_press("move_up")
	for i in 3:
		await physics_frame
	_check("奔跑中按 W -> is_sprinting = true", _player.is_sprinting == true)
	_check("奔跑中按 W -> 状态 = MoveState", _state() == &"MoveState", "实际 %s" % _state())
	_check("奔跑中按 W -> 动画 = walk_up", _anim() == &"walk_up", "实际 %s" % _anim())
	_check("奔跑中按 W -> 速度仍为 run_speed",
		is_equal_approx(_player.current_speed(), _player.stats.run_speed),
		"实际 %.1f" % _player.current_speed())
	await _release_all()


func _finish() -> void:
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("\n=== 结果：%d 项检查，%d 项失败 ===" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
