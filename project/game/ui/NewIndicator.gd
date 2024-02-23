extends Label

func _ready() -> void:
	_on_resized()

func _on_resized() -> void:
	pivot_offset = size / 2
