extends Button
# TODO: DELETE THIS AFTER TESTING FB STUFF
   
func _pressed():
	print("yello")
	var facebook_plugin = Engine.get_singleton("GodotFacebook")
	facebook_plugin.login_response.connect(_on_login_status)
	facebook_plugin.login(["email", "public_profile", "user_friends"])
   
func _on_login_status(code: int, data: Dictionary):
	print(data)
