extends Node2D

const COUNTER_DELAY_STARTUP = .3

@onready var GridNode: GridView = $CenterContainer/GridView
@onready var Counters = {
	"water": $Counters/WaterCounter,
	"boat": $Counters/BoatCounter,
	"mistake": $Counters/MistakeCounter,
}

var update_expected_waters : bool
var update_expected_boats : bool

var grid: GridModel = null
var back_grid: GridModel = null

func _ready():
	await TransitionManager.transition_finished
	
	AudioManager.play_bgm("main")
	setup()


func setup():
	if back_grid:
		$PlaytestOrBack.text = "Back"
		$PlaytestOrBack.show()
	elif grid.editor_mode():
		$PlaytestOrBack.text = "Playtest"
		$PlaytestOrBack.show()
	else:
		$PlaytestOrBack.hide()
	$BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	update_expected_waters = GridNode.get_expected_waters() > 0
	update_expected_boats = GridNode.get_expected_boats() > 0
	Counters.water.visible = GridNode.get_expected_waters() != 0
	Counters.boat.visible = GridNode.get_expected_boats() != 0
	update_counters()
	var delay = 0.0
	for counter in Counters.values():
		delay += COUNTER_DELAY_STARTUP
		counter.startup(delay)
	AudioManager.play_sfx("start_level")


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_missing_boats())


func win():
	AudioManager.play_sfx("win_level")


func _on_solve_button_pressed():
	GridNode.auto_solve()


func _on_brush_picker_brushed_picked(mode : E.BrushMode):
	GridNode.set_brush_mode(mode)


func _on_grid_updated():
	update_counters()
	if GridNode.is_level_finished():
		win()


func _on_playtest_or_back_pressed():
	if back_grid != null:
		grid = back_grid
		back_grid = null
		$PlaytestOrBack.text = "Playtest"
	else:
		back_grid = grid
		grid = GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Solution)
		$PlaytestOrBack.text = "Back"
	setup()

