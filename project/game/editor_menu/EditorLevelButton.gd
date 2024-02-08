extends Control

const IMG_FILE := "user://level_preview.png"

signal play(id: String)
signal edit(id: String)
signal delete(id: String)

var id: String

@onready var UploadButton: Button = $UploadButton

func _ready() -> void:
	UploadButton.disabled = not SteamManager.enabled


func setup(id_: String, full_name: String) -> void:
	id = id_
	$PlayButton.text = full_name


func _on_play_button_pressed():
	play.emit(id)


func _on_delete_button_pressed():
	if ConfirmationScreen.start_confirmation():
		if await ConfirmationScreen.pressed:
			delete.emit(id)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _create_grid_image(grid_logic: GridModel) -> void:
	const BASE_SIZE := 1024.0
	var v := SubViewport.new()
	var bg := ColorRect.new()
	bg.color = Color(0.192, 0.69, 0.69)
	var w := BASE_SIZE
	var h := BASE_SIZE
	if grid_logic.rows() < grid_logic.cols():
		h = BASE_SIZE * grid_logic.rows() / grid_logic.cols()
	else:
		w = BASE_SIZE * grid_logic.cols() / grid_logic.rows()
	bg.size = Vector2(w, h)
	v.size = bg.size
	bg.z_index = -10
	v.add_child(bg)
	var view: GridView = preload("res://game/level/GridView.tscn").instantiate()
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.add_child(view)
	add_child(v)
	view.setup(grid_logic, true)
	await RenderingServer.frame_post_draw
	var sz := view.get_grid_size()
	var sc := minf(w / sz.x, h / sz.y)
	view.scale = Vector2(sc, sc)
	view.position = bg.size / 2.0
	await RenderingServer.frame_post_draw
	var tex := v.get_texture()
	var img := tex.get_image()
	img.save_png(IMG_FILE)
	remove_child(v)


func _is_unique_str(grid: GridModel) -> String:
	grid.force_editor_mode(true)
	var start_time := Time.get_ticks_msec()
	var r := SolverModel.new().full_solve(grid, SolverModel.STRATEGY_LIST.keys(), func(): return Time.get_ticks_msec() - start_time > 5000)
	return Level.solve_result_to_uniqueness(r)


func _on_upload_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
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
	var unique_str := _is_unique_str(loaded)
	var tags: Array[String] = []
	if unique_str == "YES":
		tags.append("Unique solution")
	elif unique_str == "NO":
		tags.append("Multiple solutions")
	var description := level_data.description
	if description != "":
		description = description.rstrip("\n") + "\n\n"
	# Always english for this string.
	var en_tr := TranslationServer.get_translation_object("en")
	description += "%s %s" % [en_tr.get_message("HAS_UNIQUE"), en_tr.get_message(unique_str)]
	var metadata := FileManager.load_editor_level_metadata(id)
	var res = await SteamManager.upload_ugc_item(metadata.steam_id, level_data.full_name, description, FileManager._editor_level_dir(id), IMG_FILE, tags)
	if res.id != -1 and metadata.steam_id != res.id:
		metadata.steam_id = res.id
		FileManager.save_editor_level(id, metadata, null)
	if not res.success:
		push_error("Failed to upload to workshop")
	var err := DirAccess.remove_absolute(IMG_FILE)
	if err != Error.OK:
		push_warning("Failed to delete image preview: %d" % err)
	UploadButton.disabled = false
	SteamManager.steam.activateGameOverlayToWebPage("https://steamcommunity.com/sharedfiles/filedetails/?id=%s" % metadata.steam_id)


func _on_edit_button_pressed():
	edit.emit(id)
