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

func _profile_save() -> String:
	return "%s/profile.save" % _profile_dir()

func load_profile() -> void:
	if not FileAccess.file_exists(_profile_save()):
		push_warning("Profile file not found. Starting a new profile file.")
		save_profile()
		
	var profile_file := FileAccess.open(_profile_save(), FileAccess.READ)
	if profile_file == null:
		push_error("Error trying to open profile whilst loading: %d" % FileAccess.get_open_error())
		
	while profile_file.get_position() < profile_file.get_length():
		# Get the saved dictionary from the next line in the save file
		var test_json_conv := JSON.new()
		test_json_conv.parse(profile_file.get_line())
		var data = test_json_conv.get_data()
		Profile.set_save_data(data)
		break


func save_profile() -> void:
	var profile_data := Profile.get_save_data()
	if not DirAccess.dir_exists_absolute(_profile_dir()):
		DirAccess.make_dir_absolute(_profile_dir())
	var profile_file := FileAccess.open(_profile_save(), FileAccess.WRITE)
	if profile_file == null:
		push_error("Error trying to open profile whilst saving: %d" % FileAccess.get_open_error())
	profile_file.store_line(JSON.stringify(profile_data))
