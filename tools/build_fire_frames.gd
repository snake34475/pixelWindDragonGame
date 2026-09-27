extends SceneTree
## 从 assets/effects/fire/红焰_00000.png 起按顺序生成 SpriteFrames。

const FRAME_COUNT := 120
const FRAME_PATH_FORMAT := "res://assets/effects/fire/红焰_%05d.png"
const OUTPUT_PATH := "res://resources/effects/fire_frames.tres"


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"fire")
	for i in FRAME_COUNT:
		var texture := load(FRAME_PATH_FORMAT % i) as Texture2D
		if texture == null:
			push_error("缺少火焰帧 -> %s" % (FRAME_PATH_FORMAT % i))
			quit(1)
			return
		frames.add_frame(&"fire", texture)
	frames.set_animation_loop(&"fire", true)
	frames.set_animation_speed(&"fire", 24.0)
	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("保存火焰 SpriteFrames 失败: %d" % error)
		quit(1)
		return
	print("已写出 %s（%d 帧）" % [OUTPUT_PATH, FRAME_COUNT])
	quit(0)
