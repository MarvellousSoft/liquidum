extends Node2D

@onready var GridNode: GridView = $CenterContainer/GridView
@onready var Counters = {
	"water": $Counters/WaterCounter,
	"boat": $Counters/BoatCounter,
	"mistake": $Counters/MistakeCounter,
}

var update_expected_waters : bool
var update_expected_boats : bool

func _ready():
	randomize()
	AudioManager.play_bgm("main")
	setup("""
+boats=1
+waters=-1
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
	update_expected_waters = GridNode.get_expected_waters() > 0
	update_expected_boats = GridNode.get_expected_boats() > 0
	Counters.water.visible = GridNode.get_expected_waters() != 0
	Counters.boat.visible = GridNode.get_expected_boats() != 0
	update_counters()


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_missing_boats())


func _on_solve_button_pressed():
	GridNode.auto_solve()


func _on_brush_picker_brushed_picked(mode : E.BrushMode):
	GridNode.set_brush_mode(mode)


func _on_grid_updated():
	update_counters()
