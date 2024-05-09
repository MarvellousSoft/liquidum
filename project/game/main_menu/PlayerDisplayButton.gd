class_name PlayerDisplayButton
extends Control

signal pressed

func _ready():
	if Global.is_demo or not PlayFabIntegration.available():
		hide()
	else:
		show()
		update_info()
		update_flair()

static func get_display_name() -> String:
	var display_name := StoreIntegrations.playfab.current_display_name()
	if display_name == "" and SteamManager.enabled:
		display_name = SteamManager.steam.getPersonaName()
	if display_name == "":
		display_name = "YOU"
	return display_name

static func get_icon() -> Texture:
	# If we use avatar url in the future, download it here
	var icon: Texture = null
	if icon == null and SteamManager.enabled:
		SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_LARGE, SteamManager.steam.getSteamID())
		var ret: Array = await SteamManager.steam.avatar_loaded
		var image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
		if image != null:
			image.generate_mipmaps()
			icon = ImageTexture.create_from_image(image)
	if icon == null:
		icon = load("res://assets/images/icons/icon.png")
	return icon


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
			%Plus.text = "+%d" % (int(amount) - 1)
		else:
			%Plus.hide()
	else:
		%FlairContainer.hide()


func _on_button_pressed():
	pressed.emit()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
