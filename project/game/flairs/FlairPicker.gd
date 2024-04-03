extends Control

const DEFAULT_IMAGE = preload("res://assets/images/icons/icon.png")
const FLAIR_BUTTON = preload("res://game/flairs/FlairButton.tscn")

func _ready():
	populate_flairs()
	update_steam_info()
	update_flair()


func reset_flairs():
	for flair in %FlairList.get_children():
		flair.queue_free()


func populate_flairs():
	reset_flairs()
	var cur_flair = FlairManager.get_current_flair()
	var idx = 0
	for flair_data in FlairManager.get_flair_list():
		var new_flair = FLAIR_BUTTON.instantiate()
		new_flair.setup(flair_data, idx)
		new_flair.pressed.connect(_on_flair_button_pressed)
		%FlairList.add_child(new_flair)
		if flair_data.text == cur_flair.text:
			new_flair.press()
		idx += 1


func update_steam_info():
	%Name.text = SteamManager.steam.getPersonaName()
	SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_LARGE, SteamManager.steam.getSteamID())
	var ret: Array = await SteamManager.steam.avatar_loaded
	var image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
	if image != null:
		image.generate_mipmaps()
		%Image.texture = ImageTexture.create_from_image(image)
	else:
		%Image.texture = DEFAULT_IMAGE


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
	


func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
