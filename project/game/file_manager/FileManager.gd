extends Node

const CURRENT_PROFILE := "user://cur_profile.txt"
const DATA_DIR := "res://database/levels"
const DEFAULT_PROFILE := "fish"
const PROFILE_FILE := "profile.save"
const METADATA := ".metadata"
const JSON_EXT := ".json"
const LEVEL_FILE := "level.json"
const USER_DATA := "user.data"

var current_profile := DEFAULT_PROFILE


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_CRASH or what == Node.NOTIFICATION_EXIT_TREE:
		save_profile()


func save_and_quit() -> void:
	save_game()
	Global.exit_game()


func save_game() -> void:
	save_current_profile()
	save_profile()


func load_game() -> void:
	load_current_profile()
	load_profile()


func load_current_profile() -> void:
	if not FileAccess.file_exists(CURRENT_PROFILE):
		return change_current_profile(DEFAULT_PROFILE)
	var file := FileAccess.open(CURRENT_PROFILE, FileAccess.READ)
	var profile_name := file.get_as_text().strip_edges()
	if profile_name.is_valid_identifier():
		current_profile = profile_name
	else:
		current_profile = DEFAULT_PROFILE


func save_current_profile() -> void:
	var file := FileAccess.open(CURRENT_PROFILE, FileAccess.WRITE)
	file.store_string(current_profile)


func change_current_profile(profile: String) -> void:
	current_profile = profile
	save_current_profile()
	load_profile()


func get_current_profile() -> String:
	return current_profile

# Does not clear editor levels
func clear_whole_profile(profile: String) -> void:
	clear_profile(profile)
	LevelLister.clear_all_level_saves(profile)
	clear_user_data(profile)
	if profile == current_profile:
		# Reload stuff if necessary
		change_current_profile(profile)

func _profile_dir(profile := "") -> String:
	if profile.is_empty():
		profile = current_profile
	return "user://%s" % profile

func _assert_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _load_json_data(dir_name: String, file_name: String, error_non_existing := true) -> Variant:
	file_name = "%s/%s" % [dir_name, file_name]
	var file := FileAccess.open(file_name, FileAccess.READ)
	if file == null:
		if error_non_existing or FileAccess.get_open_error() != Error.ERR_FILE_NOT_FOUND:
			push_error("Error trying to open %s whilst loading: %d" % [file_name, FileAccess.get_open_error()])
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


func _delete_file(dir_name: String, file_name: String) -> void:
	file_name = "%s/%s" % [dir_name, file_name]
	if FileAccess.file_exists(file_name):
		DirAccess.remove_absolute(file_name)


# TODO: Rename to settings
func load_profile() -> void:
	if not FileAccess.file_exists("%s/%s" % [_profile_dir(), PROFILE_FILE]):
		push_warning("Profile file not found. Starting a new profile file.")
		save_profile()
	Profile.set_save_data(_load_json_data(_profile_dir(), PROFILE_FILE))


func save_profile() -> void:
	var profile_data := Profile.get_save_data()
	_save_json_data(_profile_dir(), PROFILE_FILE, profile_data)


func clear_profile(profile: String) -> void:
	_delete_file(_profile_dir(profile), PROFILE_FILE)


func _level_dir(profile := "") -> String:
	return "%s/levels" % _profile_dir(profile)


func _level_file(level: String) -> String:
	return "%s.save" % level


func load_level(level_name: String, profile := "") -> UserLevelSaveData:
	return UserLevelSaveData.load_data(_load_json_data(_level_dir(profile), _level_file(level_name), false))


func save_level(level_name: String, data: UserLevelSaveData) -> void:
	_save_json_data(_level_dir(), _level_file(level_name), data.get_data())


func clear_level(level_name: String, profile := "") -> void:
	_delete_file(_level_dir(profile), _level_file(level_name))


func level_has_solution(level_name: String, profile: String) -> bool:
	return not load_level(level_name, profile).grid_data.is_empty()


func _editor_metadata_dir(profile := "") -> String:
	return "%s/editor" % _profile_dir(profile)


func _editor_level_dir(id: String, profile := "") -> String:
	return "%s/%s" % [_editor_metadata_dir(profile), id]


func load_editor_levels() -> Dictionary:
	var ans = {}
	if DirAccess.dir_exists_absolute(_editor_metadata_dir()):
		for file in DirAccess.get_files_at(_editor_metadata_dir()):
			if file.ends_with(METADATA):
				var id := file.substr(0, file.length() - METADATA.length())
				ans[id] = EditorLevelMetadata.load_data(_load_json_data(_editor_metadata_dir(), file))
	return ans


func save_editor_level(id: String, metadata: EditorLevelMetadata, data: LevelData) -> void:
	if metadata != null:
		_save_json_data(_editor_metadata_dir(), id + METADATA, metadata.get_data())
	if data != null:
		_save_json_data(_editor_level_dir(id), LEVEL_FILE, data.get_data())


func load_editor_level(id: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_editor_level_dir(id), LEVEL_FILE))
	return data


func load_editor_level_metadata(id: String) -> EditorLevelMetadata:
	return EditorLevelMetadata.load_data(_load_json_data(_editor_metadata_dir(), id + METADATA))


func clear_editor_level(id: String, profile := "") -> void:
	_delete_file(_editor_level_dir(id, profile), LEVEL_FILE)
	_delete_file(_editor_metadata_dir(profile), id + METADATA)

func _no_tutorial(data: LevelData) -> void:
	if data != null:
		assert(data.tutorial.is_empty(), "Level can't have tutorial")
		data.tutorial = ""

func _has_difficulty(data: LevelData) -> void:
	if data != null:
		assert(data.difficulty != -1, "Random level must have difficulty")
		if data.difficulty == -1:
			data.difficulty = RandomHub.Difficulty.Easy

func load_workshop_level(dir: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(dir, LEVEL_FILE))
	_no_tutorial(data)
	return data

const RANDOM := "random.json"

func load_random_level() -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_dir(), RANDOM))
	_has_difficulty(data)
	_no_tutorial(data)
	return data

func save_random_level(data: LevelData) -> void:
	_has_difficulty(data)
	_no_tutorial(data)
	_save_json_data(_level_dir(), RANDOM, data.get_data())

func _daily_basename(date: String) -> String:
	return "daily_%s" % date

func load_daily_level(date: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_dir(), _daily_basename(date) + JSON_EXT))
	_no_tutorial(data)
	return data

func save_daily_level(date: String, data: LevelData) -> void:
	_no_tutorial(data)
	_save_json_data(_level_dir(), _daily_basename(date) + JSON_EXT, data.get_data())

func has_daily_level(date: String) -> bool:
	return FileAccess.file_exists("%s/%s%s" % [_level_dir(), _daily_basename(date), JSON_EXT])

func _level_data_dir(section: int) -> String:
	return "%s/%02d" % [DATA_DIR, section]


func _level_data_file(level: int) -> String:
	return "%02d.json" % level


func has_level_data(section: int, level: int) -> bool:
	return FileAccess.file_exists("%s/%s" % [_level_data_dir(section), _level_data_file(level)])


func load_level_data(section: int, level: int) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_data_dir(section), _level_data_file(level)))
	assert(not data.full_name.is_empty())
	return data

# If this becomes very used, we can cache it
func _load_user_data() -> UserData:
	return UserData.load_data(_load_json_data(_profile_dir(), USER_DATA, false))


func _save_user_data(data: UserData) -> void:
	_save_json_data(_profile_dir(), USER_DATA, data.get_data())


func clear_user_data(profile: String) -> void:
	_delete_file(_profile_dir(profile), USER_DATA)
