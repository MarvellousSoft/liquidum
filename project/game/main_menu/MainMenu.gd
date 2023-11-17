extends Node2D

@onready var Version = $Version

func _ready():
	FileManager.load_game()
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION
	randomize()
	
	var level = preload("res://game/level/Level.tscn").instantiate()
	level.grid = GridImpl.from_str("""
+boats=1
+waters=10
B.......
.h6.4.2.
11##bb.w
..L.|..╲
.4wwww..
..|╲./|.
.4www..w
..L../.╲
.3www...
..L._╲|.""", GridModel.LoadMode.Editor)
	TransitionManager.change_scene(level)


