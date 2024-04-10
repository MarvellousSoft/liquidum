extends ModulateTextureButton

func _ready() -> void:
	if not AppleIntegration.available() and not GoogleIntegration.available():
		queue_free()

func _on_pressed() -> void:
	await StoreIntegrations.show_achievements()
