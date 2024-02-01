class_name SettingsScreen
extends CanvasLayer

signal pause_toggled(active : bool)

@onready var AnimPlayer = $AnimationPlayer
@onready var SoundSettings = {
	"master": %MasterSoundContainer/HSlider,
	"bgm": %BGMSoundContainer/HSlider,
	"sfx": %SFXSoundContainer/HSlider,
}
@onready var Fullscreen = %FullscreenContainer/CheckBox
@onready var BG = $BG
@onready var PauseButton: TextureButton = $PauseButton
@onready var TitleContainer = %TitleContainer
@onready var LevelTitle = %LevelTitle
@onready var LevelID = %LevelID

var active := false
var is_disabled := false

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	TitleContainer.hide()
	BG.hide()
	if Global.is_mobile:
		update_remove_ads_button()
		AdManager.ads_disabled.connect(update_remove_ads_button)


func update_remove_ads_button() -> void:
	if Global.is_mobile:
		%RemoveAdsButton.visible = not AdManager.disabled
		%RemoveAdsButton.disabled = (AdManager.payment == null)


func disable_button():
	is_disabled = true
	create_tween().tween_property(PauseButton, "modulate:a", 0.5, 1)
	PauseButton.disabled = true


func enable_button():
	is_disabled = false
	PauseButton.disabled = false


func hide_button():
	PauseButton.hide()


func show_button():
	PauseButton.show()


func toggle_pause() -> void:
	if is_disabled:
		return
	active = not active
	if active:
		AudioManager.play_sfx("enable_settings")
		setup_values()
		AnimPlayer.play("enable")
	else:
		AudioManager.play_sfx("disable_settings")
		save_values()
		AnimPlayer.play("disable")
	pause_toggled.emit(active)


func save_values(do_save := true) -> void:
	Profile.set_option("master_volume", SoundSettings.master.get_value()/100.0)
	Profile.set_option("bgm_volume", SoundSettings.bgm.get_value()/100.0)
	Profile.set_option("sfx_volume", SoundSettings.sfx.get_value()/100.0)
	Profile.set_option("fullscreen", Fullscreen.button_pressed)
	if do_save:
		FileManager.save_profile()


func setup_values() -> void:
	SoundSettings.master.set_value(Profile.get_option("master_volume")*100)
	SoundSettings.bgm.set_value(Profile.get_option("bgm_volume")*100)
	SoundSettings.sfx.set_value(Profile.get_option("sfx_volume")*100)
	Fullscreen.button_pressed = Global.is_fullscreen()
	%HighlightLinesContainer/CheckBox.button_pressed = Profile.get_option("highlight_grid")
	%ShowPreviewContainer/CheckBox.button_pressed = Profile.get_option("show_grid_preview")
	%LanguageSelectContainer/OptionButton.selected = Profile.get_option("locale")
	%DarkModeContainer/CheckBox.button_pressed = Profile.get_option("dark_mode")
	%DragContainer/CheckBox.button_pressed = Profile.get_option("drag_content")
	%InvertMouseContainer/CheckBox.button_pressed = Profile.get_option("invert_mouse")
	%IncompleteInfoContainer/OptionButton.selected = Profile.get_option("line_info")
	%VsyncContainer/OptionButton.selected = Profile.get_option("vsync")
	%ShowTimerContainer/CheckBox.button_pressed = Profile.get_option("show_timer")
	%AllowMistakesContainer/CheckBox.button_pressed = Profile.get_option("allow_mistakes")
	%ProgressOnUnknownContainer/CheckBox.button_pressed = Profile.get_option("progress_on_unknown")


func set_level_name(level_name: String, section := -1, level := -1) ->  void:
	if level_name != "":
		TitleContainer.show()
		LevelTitle.text = level_name
		if level != -1 and section != -1:
			LevelID.show()
			LevelID.text = "%d - %d" % [section, level]
		else:
			LevelID.hide()
	else:
		TitleContainer.hide()


func _on_volume_slider_value_changed(value, bus : int):
	AudioManager.set_bus_volume(bus, float(value)/100.0)


func _on_pause_button_pressed():
	toggle_pause()

func checkbox_sound(on: bool) -> void:
	if on:
		AudioManager.play_sfx("checkbox_pressed")
	else:
		AudioManager.play_sfx("checkbox_unpressed")
	

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if Global.is_fullscreen() != button_pressed:
		Global.toggle_fullscreen()
	checkbox_sound(button_pressed)


func _on_save_n_quit_button_pressed():
	AudioManager.play_sfx("button_back")
	save_values(false)
	Global.exit_game()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_dark_mode_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("dark_mode", on)
	Profile.dark_mode_toggled.emit(on)


func _on_highlight_lines_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("highlight_grid", on)


func _on_show_preview_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("show_grid_preview", on)


func _on_drag_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("drag_content", on)


func _on_invert_mouse_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("invert_mouse", on)


func _on_language_item_selected(index: int) -> void:
	checkbox_sound(true)
	Profile.set_option("locale", index)
	Profile.update_translation()


func _on_line_info_item_selected(index: int) -> void:
	checkbox_sound(true)
	Profile.set_option("line_info", index)
	Profile.line_info_changed.emit()


func _on_back_button_pressed():
	save_values()
	FileManager.save_game()
	toggle_pause()


func _on_vsync_mode_selected(vsync_mode: int) -> void:
	checkbox_sound(true)
	Profile.set_option("vsync", vsync_mode)
	DisplayServer.window_set_vsync_mode(vsync_mode)


func _on_remove_ads_button_pressed() -> void:
	AdManager.buy_ad_removal()


func _on_show_timer_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("show_timer", on)
	Profile.show_timer_changed.emit(on)


func _on_allow_mistakes_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("allow_mistakes", on)
	Profile.allow_mistakes_changed.emit(on)


func _on_progress_on_unknown_toggled(on: bool) -> void:
	checkbox_sound(on)
	Profile.set_option("progress_on_unknown", on)
	Profile.progress_on_unkown_changed.emit(on)


func _on_dark_mode_changed(is_dark : bool):
	%Settings.theme = Global.get_settings_theme(is_dark)
	if Global.is_mobile:
		for node in [%RemoveAdsButton, %BackButton, %QuitButton]:
			node.theme = Global.get_theme(is_dark)
	else:
		for node in [%BackButton, %QuitButton]:
			node.theme = Global.get_theme(is_dark)


func _on_tab_container_tab_changed(_tab):
	AudioManager.play_sfx("tab_changed")


func _on_tab_container_tab_hovered(_tab):
	AudioManager.play_sfx("tab_hover")
