class_name NpcDialog
extends Control
## 最小 NPC 对话框：显示文本，持续时间结束后发出关闭信号。

signal dialog_closed

var _remaining_time := 0.0

@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: RichTextLabel = $Panel/Text


func show_dialog(speaker: String, text: String, duration: float) -> void:
	speaker_label.text = speaker
	text_label.text = text
	_remaining_time = maxf(duration, 0.0)
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_remaining_time -= delta
	if _remaining_time <= 0.0:
		close()


func close() -> void:
	if not visible:
		return
	visible = false
	_remaining_time = 0.0
	dialog_closed.emit()
