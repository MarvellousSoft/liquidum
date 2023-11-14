extends Node2D

@onready var GridNode: GridView = $CenterContainer/GridView
@onready var Counters = {
	"water": $Counters/WaterCounter,
	"boat": $Counters/BoatCounter,
	"mistake": $Counters/MistakeCounter,
}

func _ready():
	randomize()
	AudioManager.play_bgm("main")
	setup("""
+boats=1
b.......
.h6.4.2.
11##bb.w
..L.|..╲
.4wwww..
..|╲./|.
.4www..w
..L../.╲
.3www...
..L._╲|.""")


func setup(level : String):
	GridNode.setup(level)


func _on_solve_button_pressed():
	GridNode.auto_solve()


func _on_brush_picker_brushed_picked(mode : E.BrushMode):
	GridNode.set_brush_mode(mode)
