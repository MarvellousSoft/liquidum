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
var level_name := ""

static func with_grid(grid_: GridModel, level_name_: String) -> Level:
	var level: Level = preload("res://game/level/Level.tscn").instantiate()
	level.grid = grid_
	level.level_name = level_name_
	return level

func _ready():
	await TransitionManager.transition_finished
	
	AudioManager.play_bgm("main")
	setup()

func set_timer_secs(_timer_secs_: float) -> void:
	# TODO: Timer
	pass


func setup():
	if not grid.editor_mode():
		$PlaytestButton.hide()
		if not level_name.is_empty():
			var save := FileManager.load_level(level_name)
			if save != null:
				# Maybe make this validate with original level. Not for now.
				grid = GridExporter.new().load_data(save.grid_data, GridModel.LoadMode.ContentOnly)
				Counters.mistake.set_count(save.mistakes)
				set_timer_secs(save.timer_secs)
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

func _on_playtest_button_pressed() -> void:
	var new_level := Level.with_grid(GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Solution), "")
	TransitionManager.push_scene(new_level)


func _on_back_button_pressed() -> void:
	if not level_name.is_empty():
		FileManager.save_level(level_name, UserLevelSaveData.new(GridNode.grid_logic.export_data(), Counters.mistake.count, 0.0))
	TransitionManager.pop_scene()
