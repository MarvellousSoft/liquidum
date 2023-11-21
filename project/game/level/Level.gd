class_name Level
extends Node2D

const COUNTER_DELAY_STARTUP = .3

@onready var GridNode: GridView = $CenterContainer/GridView
@onready var Counters = {
	"water": $Counters/WaterCounter,
	"boat": $Counters/BoatCounter,
	"mistake": $Counters/MistakeCounter,
}
@onready var AquariumHints = $AquariumHintContainer

var update_expected_waters : bool
var update_expected_boats : bool

var grid: GridModel = null

func _ready():
	await TransitionManager.transition_finished
	
	AudioManager.play_bgm("main")
	setup()


func setup():
	if not grid.editor_mode():
		$PlaytestButton.hide()
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
	delay += COUNTER_DELAY_STARTUP
	AquariumHints.startup(delay)
	AudioManager.play_sfx("start_level")

func editor_mode() -> bool:
	return GridNode.editor_mode


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_expected_waters() if GridNode.editor_mode else GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_expected_boats() if GridNode.editor_mode else GridNode.get_missing_boats())


func win():
	AudioManager.play_sfx("win_level")


func _on_solve_button_pressed():
	GridNode.auto_solve()


func _on_brush_picker_brushed_picked(mode : E.BrushMode):
	GridNode.set_brush_mode(mode)


func _on_grid_updated():
	update_counters()
	if GridNode.is_level_finished() and not editor_mode():
		win()

func _on_playtest_button_pressed():
	var new_level: Level = preload("res://game/level/Level.tscn").instantiate()
	new_level.grid = GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Solution)
	TransitionManager.push_scene(new_level)


func _on_back_button_pressed():
	TransitionManager.pop_scene()
