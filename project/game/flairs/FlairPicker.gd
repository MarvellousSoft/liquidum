class_name FlairPicker
extends Control

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	populate_flairs()
	update_info()
	update_flair()
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	

func reset_flairs():
	for flair in %FlairList.get_children():
		flair.queue_free()


func populate_flairs():
	reset_flairs()
	var cur_flair = FlairManager.get_current_flair()
	var flair_cls: PackedScene = load("res://game/flairs/FlairButton.tscn")
	for flair_data in FlairManager.get_flair_list():
		var new_flair: FlairButton = flair_cls.instantiate()
		new_flair.setup(flair_data)
		new_flair.pressed.connect(_on_flair_button_pressed)
		%FlairList.add_child(new_flair)
		if cur_flair and flair_data.id == cur_flair.id:
			new_flair.press()
	if not cur_flair:
		%FlairList.get_child(0).press()

func update_info():
	%Name.text = PlayerDisplayButton.get_display_name()
	%Image.texture = await PlayerDisplayButton.get_icon()


func update_flair():
	var cur_flair = FlairManager.get_current_flair()
	if cur_flair:
		%FlairContainer.show()
		%Flair.text = "  %s  " % cur_flair.text
		%Flair.add_theme_color_override("font_color", cur_flair.color)
		var contrast_color = Global.get_contrast_background(cur_flair.color)
		%Flair.get_node("BG").modulate = contrast_color
		var amount = FlairManager.get_flair_amount() 
		if amount > 1:
			%Plus.show()
			%Plus.text = "+%d" % (amount-1)
		else:
			%Plus.hide()
	else:
		%FlairContainer.hide()


func _on_flair_button_pressed(flair_node):
	for node in %FlairList.get_children():
		if node != flair_node:
			node.unpress()
	if flair_node.is_pressed():
		FlairManager.set_selected_flair_id(flair_node.id)
	else:
		FlairManager.set_selected_flair_id(-1)
	update_flair()
	

static func save_flair() -> void:
	var cur_flair := FlairManager.get_current_flair()
	await StoreIntegrations.leaderboard_upload_score(
		"flair", float(cur_flair.to_steam_flair().encode_to_int() if cur_flair != null else -1), false
	)

func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	FlairPicker.save_flair()
	TransitionManager.pop_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_edit_name_pressed() -> void:
	if not %Name.visible:
		return
	%NameEdit.text = %Name.text
	%Name.hide()
	%NameEdit.show()
	%NameEdit.grab_focus()
	%EditButton.hide()
	%UploadButton.show()


func _on_upload_name_pressed() -> void:
	if %Name.visible or %NameLoading.visible:
		return
	var new_name: String = %NameEdit.text
	var old_name: String = %Name.text
	%UploadButton.hide()
	%NameLoading.show()
	%NameEdit.hide()
	%Name.text = new_name
	%Name.show()
	if await StoreIntegrations.playfab.change_display_name(new_name):
		%NameLoading.hide()
		%EditButton.show()
	else:
		AudioManager.play_sfx("error")
		%Name.hide()
		%Name.text = old_name
		%NameEdit.show()
		%NameLoading.hide()
		%UploadButton.show()


func _on_name_edit_text_submitted(_new_text):
	await _on_upload_name_pressed()


func _on_dark_mode_changed(is_dark : bool):
	var color = Color(1.0, 1.0, 1.0) if is_dark else Color(0, 0.035, 0.141)
	for node in [%EditButton, %UploadButton]:
		node.modulate = color
