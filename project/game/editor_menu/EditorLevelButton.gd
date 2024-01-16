extends Control

signal play(id: String)
signal edit(id: String)
signal delete(id: String)

var id: String

@onready var UploadButton: Button = $UploadButton

func setup(id_: String, full_name: String) -> void:
	id = id_
	$PlayButton.text = full_name

func _ready() -> void:
	UploadButton.disabled = not SteamManager.enabled

func _on_play_button_pressed():
	play.emit(id)

func _on_delete_button_pressed():
	if ConfirmationScreen.start_confirmation():
		if await ConfirmationScreen.pressed:
			delete.emit(id)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")

const IMG_FILE := "user://level_preview.png"

func _create_grid_image(grid_logic: GridModel) -> void:
	var v := SubViewport.new()
	var bg := ColorRect.new()
	bg.color = Color(0.192, 0.69, 0.69)
	bg.size = Vector2(512, 512)
	bg.z_index = -10
	v.add_child(bg)
	var view: GridView = preload("res://game/level/GridView.tscn").instantiate()
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.add_child(view)
	add_child(v)
	view.setup(grid_logic, true)
	await RenderingServer.frame_post_draw
	var sz := view.get_grid_size()
	view.scale = Vector2(512.0 / sz.x, 512.0 / sz.y)
	view.position = Vector2(256, 256)
	await RenderingServer.frame_post_draw
	var img := v.get_texture().get_image()
	img.save_png(IMG_FILE)
	remove_child(v)

func _on_upload_button_pressed() -> void:
	if not SteamManager.enabled:
		return
	UploadButton.disabled = true
	var level_data := FileManager.load_editor_level(id)
	var loaded := GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.SolutionNoClear)
	if loaded.count_waters() == 0:
		push_warning("Not uploading empty level")
		return
	loaded.clear_content()
	await _create_grid_image(loaded)
	var metadata := FileManager.load_editor_level_metadata(id)
	var res = await SteamManager.upload_ugc_item(metadata.steam_id, level_data.full_name, level_data.description, FileManager._editor_level_dir(id), IMG_FILE)
	if res.id != -1 and metadata.steam_id != res.id:
		metadata.steam_id = res.id
		FileManager.save_editor_level(id, metadata, null)
	if not res.success:
		push_error("Failed to upload to workshop")
	var err := DirAccess.remove_absolute(IMG_FILE)
	if err != Error.OK:
		push_warning("Failed to delete image preview: %d" % err)
	UploadButton.disabled = false


func _on_edit_button_pressed():
	edit.emit(id)
