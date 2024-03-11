extends ModulateTextureButton

func _ready() -> void:
	if AdManager.disabled:
		queue_free()
		return
	AdManager.ads_disabled.connect(_on_disable_ads)

func _on_disable_ads() -> void:
	queue_free()

func _pressed() -> void:
	AdManager.buy_ad_removal()
