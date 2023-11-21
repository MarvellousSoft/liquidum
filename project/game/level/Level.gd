class_name Level
extends Node2D

const COUNTER_DELAY_STARTUP = .3

@onready var GridNode: GridView = %GridView
@onready var TimerLabel = %TimerLabel
@onready var CountersPanel = %CountersPanel
@onready var Counters = {
	"water": %WaterCounter,
	"boat": %BoatCounter,
	"mistake": %MistakeCounter,
}
@onready var AquariumHints = %AquariumHintContainer
@onready var AnimPlayer = $AnimationPlayer

var update_expected_waters : bool
var update_expected_boats : bool
var process_game := false
var running_time : float
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


func _process(dt):
	if process_game:
		running_time += dt
		update_timer_label()


func setup():
	running_time = 0
	
	if not grid.editor_mode():
		$PlaytestButton.hide()
		if not level_name.is_empty():
			var save := FileManager.load_level(level_name)
			if save != null:
				# Maybe make this validate with original level. Not for now.
				grid = GridExporter.new().load_data(grid, save.grid_data, GridModel.LoadMode.ContentOnly)
				Counters.mistake.set_count(save.mistakes)
				set_timer_secs(save.timer_secs)
	$BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	update_expected_waters = GridNode.get_expected_waters() > 0
	update_expected_boats = GridNode.get_expected_boats() > 0
	Counters.water.visible = GridNode.get_expected_waters() != 0
	Counters.boat.visible = GridNode.get_expected_boats() != 0
	update_counters()
	
	AnimPlayer.play("startup")
	var delay = COUNTER_DELAY_STARTUP
	for counter in Counters.values():
		delay += COUNTER_DELAY_STARTUP
		counter.startup(delay)
	delay += COUNTER_DELAY_STARTUP
	AquariumHints.startup(delay)
	
	AudioManager.play_sfx("start_level")
	
	process_game = true


func editor_mode() -> bool:
	return GridNode.editor_mode


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_expected_waters() if GridNode.editor_mode else GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_expected_boats() if GridNode.editor_mode else GridNode.get_missing_boats())


func update_timer_label() -> void:
	var t = int(running_time)
	var hours = t/3600
	var minutes = t%3600/60
	var seconds = t%60
	if hours > 0:
		TimerLabel.text = "%02d:%02d:%02d" % [hours,minutes,seconds]
	else:
		TimerLabel.text = "%02d:%02d" % [minutes,seconds]

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


func _on_settings_screen_pause_toggled(active):
	process_game = not active
