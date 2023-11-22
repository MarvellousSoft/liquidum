extends CanvasLayer

signal pause_toggled(active : bool)

@onready var AnimPlayer = $AnimationPlayer
@onready var SoundSettings = {
	"master": $Settings/CenterContainer/VBoxContainer/MasterSoundContainer/HSlider,
	"bgm": $Settings/CenterContainer/VBoxContainer/BGMSoundContainer/HSlider,
	"sfx": $Settings/CenterContainer/VBoxContainer/SFXSoundContainer/HSlider,
}
@onready var Fullscreen = $Settings/CenterContainer/VBoxContainer/FullscreenContainer/CheckBox
@onready var  BG = $BG

var active := false

func _ready():
	BG.hide()
	setup_values()


func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	active = not active
	if active:
		AnimPlayer.play("enable")
	else:
		save_values()
		AnimPlayer.play("disable")
	emit_signal("pause_toggled", active)


func save_values():
	Profile.set_option("master_volume", SoundSettings.master.get_value()/100.0)
	Profile.set_option("bgm_volume", SoundSettings.bgm.get_value()/100.0)
	Profile.set_option("sfx_volume", SoundSettings.sfx.get_value()/100.0)
	Profile.set_option("fullscreen", Fullscreen.button_pressed)
	FileManager.save_profile()


func setup_values():
	SoundSettings.master.set_value(Profile.get_option("master_volume")*100)
	SoundSettings.bgm.set_value(Profile.get_option("bgm_volume")*100)
	SoundSettings.sfx.set_value(Profile.get_option("sfx_volume")*100)
	Fullscreen.button_pressed = Global.is_fullscreen()


func _on_volume_slider_value_changed(value, bus : int):
	AudioManager.set_bus_volume(bus, float(value)/100.0)


func _on_pause_button_pressed():
	toggle_pause()


func _on_fullscreen_toggled(button_pressed):
	if Global.is_fullscreen() != button_pressed:
		Global.toggle_fullscreen()


func _on_save_n_quit_button_pressed():
	FileManager.save_and_quit()
