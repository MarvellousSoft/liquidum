extends TextureButton

const NORMAL_COLOR := Color(0.671, 1, 0.82)
const HOVER_COLOR := Color(0.847, 0.996, 0.882)

func _ready() -> void:
	if AdManager.disabled:
		queue_free()
		return
	AdManager.ads_disabled.connect(_on_disable_ads)

func _on_disable_ads() -> void:
	queue_free()

func _on_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")
	modulate = HOVER_COLOR

func _on_mouse_exited() -> void:
	modulate = NORMAL_COLOR

func _pressed() -> void:
	AdManager.buy_ad_removal()
