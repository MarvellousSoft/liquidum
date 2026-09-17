class_name CustomHintModal
extends CanvasLayer

signal completed(result: Variant) # null on cancel, or String otherwise, empty to unset

@onready var AltText: LineEdit = %AltText

func _ready() -> void:
	hide()

func open(initial_text: String = "") -> Variant: # null on cancel, or String otherwise, empty to unset
	AltText.text = initial_text
	show()
	AltText.grab_focus()
	AltText.select_all()
	
	var result = await completed
	hide()
	return result

func _on_confirm() -> void:
	AudioManager.play_sfx("button_pressed")
	completed.emit(AltText.text.strip_edges())

func _on_cancel() -> void:
	AudioManager.play_sfx("button_pressed")
	completed.emit(null)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"): # Escape key
		get_viewport().set_input_as_handled()
		_on_cancel()

func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
