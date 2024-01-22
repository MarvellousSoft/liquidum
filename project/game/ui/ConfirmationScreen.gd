extends CanvasLayer

signal pressed(status : bool)

const CONTENT_THEMES = {
	"desktop": preload("res://assets/ui/SettingsTheme.tres"),
	"mobile": preload("res://assets/ui/SettingsMobileTheme.tres"),
}

const BUTTON_THEMES = {
	"desktop": preload("res://assets/ui/GeneralTheme.tres"),
	"mobile": preload("res://assets/ui/MobileTheme.tres"),
}



@onready var AnimPlayer = $AnimationPlayer
@onready var BG = $BG
@onready var MainTitle = %MainTitle
@onready var YesButton = %Yes
@onready var NoButton = %No

var active := false

func _ready():
	if Global.is_mobile:
		%CenterContainer.size = Vector2(720, 1280)
		%MainTitle.custom_minimum_size.x = 500
		%Content.theme = CONTENT_THEMES.mobile
		%Yes.theme = BUTTON_THEMES.mobile
		%No.theme = BUTTON_THEMES.mobile
	else:
		%CenterContainer.size = Vector2(3840, 2160)
		%MainTitle.custom_minimum_size.x = 3000
		%Content.theme = CONTENT_THEMES.desktop
		%Yes.theme = BUTTON_THEMES.desktop
		%No.theme = BUTTON_THEMES.desktop
	BG.hide()


func _input(event):
	if event.is_action_pressed("ui_accept") and active:
		_on_yes_pressed()
	elif event.is_action_pressed("ui_cancel") and active:
		_on_no_pressed()


func reset_texts() -> void:
	MainTitle.text = tr("DEFAULT_CONFIRMATION")
	YesButton.text = tr("YES")
	NoButton.text = tr("NO")
	

func start_confirmation(override_title := &"", override_yes := &"", override_no := &"") -> bool:
	if active:
		push_error("Already has an active confirmation screen. Aborting new one")
		return false
	reset_texts()
	if not override_title.is_empty():
		MainTitle.text = tr(override_title)
	if not override_yes.is_empty():
		YesButton.text = tr(override_yes)
	if not override_no.is_empty():
		NoButton.text = tr(override_no)
	active = true
	AnimPlayer.play("enable")
	
	return true

func _on_yes_pressed():
	AudioManager.play_sfx("button_pressed")
	active = false
	AnimPlayer.play("disable")
	pressed.emit(true)


func _on_no_pressed():
	AudioManager.play_sfx("button_pressed")
	active = false
	AnimPlayer.play("disable")
	pressed.emit(false)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
