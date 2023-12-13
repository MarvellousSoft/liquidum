extends CanvasLayer

signal cancel

@onready var Cancel: Button = $All/PanelContainer/VBoxContainer/Cancel

func enable() -> void:
	show()
	Cancel.disabled = false

func disable() -> void:
	hide()

func _on_cancel_pressed() -> void:
	cancel.emit()
	Cancel.disabled = true
