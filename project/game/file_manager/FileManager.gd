extends Node

var current_profile := "default"

func _notification(what) -> void:
	if what == MainLoop.NOTIFICATION_CRASH:
		save_profile()

func save_and_quit() -> void:
	save_game()
	get_tree().quit()

func save_game() -> void:
	save_profile()

func load_game() -> void:
	load_profile()

func _profile_dir() -> String:
	return "user://%s" % current_profile

func _assert_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _load_json_data(dir_name: String, file_name: String) -> Variant:
	file_name = "%s/%s" % [dir_name, file_name]
	var file := FileAccess.open(file_name, FileAccess.READ)
	if file == null:
		push_error("Error trying to open profile whilst loading: %d" % FileAccess.get_open_error())
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != Error.OK:
		push_error("Error parsing JSON on line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	return json.get_data()

func _save_json_data(dir_name: String, file_name: String, data: Dictionary) -> void:
	_assert_dir(dir_name)
	var file := FileAccess.open("%s/%s" % [dir_name, file_name], FileAccess.WRITE)
	if file == null:
		push_error("Error trying to open file %s/%s whilst saving: %d" % [dir_name, file_name, FileAccess.get_open_error()])
	file.store_string(JSON.stringify(data))

const PROFILE_FILE := "profile.save"

func load_profile() -> void:
	if not FileAccess.file_exists("%s/%s" % [_profile_dir(), PROFILE_FILE]):
		push_warning("Profile file not found. Starting a new profile file.")
		save_profile()
	Profile.set_save_data(_load_json_data(_profile_dir(), PROFILE_FILE))

func save_profile() -> void:
	var profile_data := Profile.get_save_data()
	_save_json_data(_profile_dir(), "profile.save", profile_data)

func _level_dir() -> String:
	return "%s/levels" % _profile_dir()

func _level_file(level: String) -> String:
	return "%s.save" % level

func load_level(level_name: String, load_mode: GridModel.LoadMode) -> LevelSaveData:
	return LevelSaveData.load_data(_load_json_data(_level_dir(), _level_file(level_name)), load_mode)

func save_level(level_name: String, data: LevelSaveData) -> void:
	_save_json_data(_level_dir(), _level_file(level_name), data.get_data())

