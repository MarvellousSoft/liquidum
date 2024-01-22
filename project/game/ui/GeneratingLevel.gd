extends CanvasLayer

signal cancel

@onready var Cancel: Button = $All/PanelContainer/VBoxContainer/Cancel

func _ready() -> void:
	$All.size = get_viewport().get_visible_rect().size

func enable() -> void:
	show()
	Cancel.disabled = false

func disable() -> void:
	hide()

func _on_cancel_pressed() -> void:
	cancel.emit()
	Cancel.disabled = true
