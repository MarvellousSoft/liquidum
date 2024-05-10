extends ModulateTextureButton

func _ready() -> void:
	super()
	_on_resized()

func _on_resized() -> void:
	pivot_offset = size / 2
