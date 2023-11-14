extends Node2D

@onready var Version = $Version

func _ready():
	FileManager.load_game()
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION
	
	randomize()
	TransitionManager.change_scene("res://game/level/Level.tscn")


