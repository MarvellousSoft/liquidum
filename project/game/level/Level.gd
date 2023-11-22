class_name Level
extends Node2D

const COUNTER_DELAY_STARTUP = .3
const DESIRED_GRID_W = 1050

@onready var GridNode: GridView = %GridView
@onready var TimerContainer = %TimerContainer
@onready var TimerLabel = %TimerLabel
@onready var CountersPanel = %CountersPanel
@onready var Counters = {
	"water": %WaterCounter,
	"boat": %BoatCounter,
	"mistake": %MistakeCounter,
}
@onready var AquariumHints: AquariumHintContainer = %AquariumHintContainer
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


func _process(dt):
	if process_game and not grid.editor_mode():
		running_time += dt
		update_timer_label()


func setup():
	running_time = 0
	
	if not level_name.is_empty():
		if grid.editor_mode():
			var data := FileManager.load_editor_level(level_name)
			if data != null:
				grid = GridExporter.new().load_data(grid, data.grid_data, GridModel.LoadMode.Editor)
		else:
			var save := FileManager.load_level(level_name)
			if save != null:
				# Maybe make this validate with original level. Not for now.
				grid = GridExporter.new().load_data(grid, save.grid_data, GridModel.LoadMode.ContentOnly)
				Counters.mistake.set_count(save.mistakes)
				running_time = save.timer_secs
	$BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	if not editor_mode():
		$PlaytestButton.hide()
		update_expected_waters = GridNode.get_expected_waters() > 0
		update_expected_boats = GridNode.get_expected_boats() > 0
		Counters.water.visible = GridNode.get_expected_waters() != -1
		Counters.boat.visible = GridNode.get_expected_boats() != 0
		CountersPanel.visible = Counters.water.visible or Counters.boat.visible
	else:
		Counters.water.visible = true
		Counters.boat.visible = true
		Counters.water.enable_editor()
		Counters.boat.enable_editor()
		Counters.mistake.hide()
		TimerContainer.hide()
	update_counters()

	AnimPlayer.play("startup")
	var delay = COUNTER_DELAY_STARTUP
	for counter in Counters.values():
		delay += COUNTER_DELAY_STARTUP
		counter.startup(delay)
	delay += COUNTER_DELAY_STARTUP
	AquariumHints.startup(delay, grid.grid_hints().expected_aquariums, grid.all_aquarium_counts(), GridNode.editor_mode)
	
	AudioManager.play_sfx("start_level")
	
	scale_grid()
	process_game = true


func editor_mode() -> bool:
	return GridNode.editor_mode


func scale_grid() -> void:
	await get_tree().process_frame
	var s := DESIRED_GRID_W / GridNode.get_grid_size().x
	GridNode.scale = Vector2(s, s)


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_expected_waters() if GridNode.editor_mode else GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_expected_boats() if GridNode.editor_mode else GridNode.get_missing_boats())
	AquariumHints.update_values(GridNode.grid_logic.grid_hints().expected_aquariums, GridNode.grid_logic.all_aquarium_counts(), GridNode.editor_mode)
	


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

func _update_line_hint(line_hint: GridModel.LineHint, boat_flags: int, water_flags: int) -> void:
	if not (boat_flags & HintBar.VALUE_VISIBLE):
		line_hint.boat_count = -1
	if not (boat_flags & HintBar.TYPE_VISIBLE):
		line_hint.boat_count_type = E.HintType.Any
	if not (water_flags & HintBar.VALUE_VISIBLE):
		line_hint.water_count = -1.0
	if not (water_flags & HintBar.TYPE_VISIBLE):
		line_hint.water_count_type = E.HintType.Any

func _on_playtest_button_pressed() -> void:
	var new_grid := GridImpl.import_data(grid.export_data(), GridModel.LoadMode.Solution)
	if not Counters.water.should_be_visible():
		new_grid.grid_hints().total_water = -1
	if not Counters.boat.should_be_visible():
		new_grid.grid_hints().total_boats = -1
	var boat_visible := GridNode.boat_row_hints_should_be_visible()
	var water_visible := GridNode.water_row_hints_should_be_visible()
	for i in new_grid.rows():
		_update_line_hint(new_grid.row_hints()[i], boat_visible[i], water_visible[i])
	boat_visible = GridNode.boat_col_hints_should_be_visible()
	water_visible = GridNode.water_col_hints_should_be_visible()
	for j in new_grid.cols():
		_update_line_hint(new_grid.col_hints()[j], boat_visible[j], water_visible[j])
	var new_level := Level.with_grid(new_grid, "")
	TransitionManager.push_scene(new_level)


func _on_back_button_pressed() -> void:
	if not level_name.is_empty():
		if editor_mode():
			FileManager.save_editor_level(level_name, null, LevelData.new("", GridNode.grid_logic.export_data()))
		else:
			FileManager.save_level(level_name, UserLevelSaveData.new(GridNode.grid_logic.export_data(), Counters.mistake.count, running_time))
	TransitionManager.pop_scene()


func _on_settings_screen_pause_toggled(active):
	process_game = not active
