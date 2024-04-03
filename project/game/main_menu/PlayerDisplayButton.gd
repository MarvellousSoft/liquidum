extends Control

const DEFAULT_IMAGE = preload("res://assets/images/icons/icon.png")

signal pressed

func _ready():
	if not SteamManager.enabled:
		hide()
	else:
		show()
		update_steam_info()
		update_flair()


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
			%Plus.text = "+%d" % (int(amount) - 1)
		else:
			%Plus.hide()
	else:
		%FlairContainer.hide()


func _on_button_pressed():
	pressed.emit()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
