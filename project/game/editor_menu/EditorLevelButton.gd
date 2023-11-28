extends Control

signal open(id: String)
signal delete(id: String)

var id: String

@onready var UploadButton: Button = $UploadButton

func setup(id_: String, full_name: String) -> void:
	id = id_
	$OpenButton.text = full_name

func _ready() -> void:
	UploadButton.disabled = not SteamManager.enabled

func _on_open_button_pressed():
	open.emit(id)


func _on_delete_button_pressed():
	if ConfirmationScreen.start_confirmation():
		if await ConfirmationScreen.pressed:
			delete.emit(id)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_upload_button_pressed() -> void:
	if not SteamManager.enabled:
		return
	UploadButton.disabled = true
	var metadata := FileManager.load_editor_level_metadata(id)
	var res := await SteamManager.upload_ugc_item(metadata.steam_id, metadata.full_name, FileManager._editor_level_dir(id))
	if res.id != -1 and metadata.steam_id != res.id:
		metadata.steam_id = res.id
		FileManager.save_editor_level(id, metadata, null)
	if not res.success:
		# TODO: Display some error
		pass
	UploadButton.disabled = false

