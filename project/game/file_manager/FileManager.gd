extends Node


func _notification(what):
	if what == MainLoop.NOTIFICATION_CRASH:
		save_profile()


func save_and_quit():
	save_game()
	get_tree().quit()


func save_game():
	save_profile()


func load_game():
	load_profile()


func load_profile():
	if not FileAccess.file_exists("user://profile.save"):
		push_warning("Profile file not found. Starting a new profile file.")
		save_profile()
		
	var profile_file = FileAccess.open("user://profile.save", FileAccess.READ)
	if not profile_file:
		push_error("Error trying to open profile whilst loading:" + str(FileAccess.get_open_error()))
		
	while profile_file.get_position() < profile_file.get_length():
		# Get the saved dictionary from the next line in the save file
		var test_json_conv = JSON.new()
		test_json_conv.parse(profile_file.get_line())
		var data = test_json_conv.get_data()
		Profile.set_save_data(data)
		break
		
	profile_file.close()


func save_profile():
	var profile_data = Profile.get_save_data()
	var profile_file
	profile_file = FileAccess.open("user://profile.save", FileAccess.WRITE)
	if not profile_file:
		push_error("Error trying to open profile whilst saving:" + str(FileAccess.get_open_error()))
	profile_file.store_line(JSON.stringify(profile_data))
	profile_file.close()
