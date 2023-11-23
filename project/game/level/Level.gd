class_name Level
extends Control

const COUNTER_DELAY_STARTUP = .3
const DESIRED_GRID_W = 1700

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
# Has completion data but outdated grid data
var dummy_save := UserLevelSaveData.new({}, 0, 0.0)

func _ready():
	GridNode.hide()
	await TransitionManager.transition_finished
	GridNode.show()
	AudioManager.play_bgm("main")
	setup()

func _enter_tree():
	if GridNode:
		scale_grid()

func _process(dt):
	if process_game and not grid.editor_mode():
		running_time += dt
		update_timer_label()

func _hint_to_flag(hint: GridModel.LineHint) -> int:
	var val := 0
	if hint.water_count != -1.:
		val |= HintBar.WATER_COUNT_VISIBLE
	if hint.water_count_type != E.HintType.Any:
		val |= HintBar.WATER_TYPE_VISIBLE
	if hint.boat_count != -1:
		val |= HintBar.BOAT_COUNT_VISIBLE
	if hint.boat_count_type != E.HintType.Any:
		val |= HintBar.BOAT_TYPE_VISIBLE
	return val

func setup(try_load := true) -> void:
	$DevButtons.setup(grid.editor_mode())
	running_time = 0
	
	var visible_aquarium_sizes = null
	var row_visible: Array[int] = []
	var col_visible: Array[int] = []
	var total_water_visible := false
	var total_boat_visible := false
	
	if not level_name.is_empty() and try_load:
		if grid.editor_mode():
			var data := FileManager.load_editor_level(level_name)
			if data != null:
				# Load with Testing to get hints then change to editor
				grid = GridExporter.new().load_data(grid, data.grid_data, GridModel.LoadMode.Testing)
				total_water_visible = (grid.grid_hints().total_water != -1.)
				total_boat_visible = (grid.grid_hints().total_boats != -1)
				visible_aquarium_sizes = grid.grid_hints().expected_aquariums
				row_visible.assign(grid.row_hints().map(_hint_to_flag))
				col_visible.assign(grid.col_hints().map(_hint_to_flag))
				grid.set_auto_update_hints(true)
		else:
			var save := FileManager.load_level(level_name)
			if save != null:
				# Maybe make this validate with original level. Not for now.
				grid = GridExporter.new().load_data(grid, save.grid_data, GridModel.LoadMode.ContentOnly)
				Counters.mistake.set_count(save.mistakes)
				running_time = save.timer_secs
				dummy_save = save
	$BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	$LeftButtons/PlaytestButton.visible = editor_mode()
	if not editor_mode():
		update_expected_waters = GridNode.get_expected_waters() > 0
		update_expected_boats = GridNode.get_expected_boats() > 0
		Counters.water.visible = GridNode.get_expected_waters() != -1
		Counters.boat.visible = GridNode.get_expected_boats() != 0
		CountersPanel.visible = Counters.water.visible or Counters.boat.visible
	else:
		Counters.water.visible = true
		Counters.boat.visible = true
		Counters.water.enable_editor()
		Counters.water.set_should_be_visible(total_water_visible)
		Counters.boat.enable_editor()
		Counters.boat.set_should_be_visible(total_boat_visible)
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
	if editor_mode() and visible_aquarium_sizes != null:
		AquariumHints.set_should_be_visible(visible_aquarium_sizes)
	if editor_mode() and not row_visible.is_empty():
		GridNode.set_counters_visibility(row_visible, col_visible)
	
	AudioManager.play_sfx("start_level")
	
	scale_grid()

	process_game = true


func editor_mode() -> bool:
	return GridNode.editor_mode


func scale_grid() -> void:
	var prev_a = GridNode.modulate.a
	GridNode.modulate.a = 0.0
	
	await get_tree().process_frame
	
	var g_size = GridNode.get_grid_size()
	var s = min( DESIRED_GRID_W / g_size.x, DESIRED_GRID_W / g_size.y )
	GridNode.scale = Vector2(s, s)
	GridNode.modulate.a = prev_a


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

func win() -> void:
	AudioManager.play_sfx("win_level")
	dummy_save.save_completion(Counters.mistake.count, running_time)
	maybe_save()


func _on_brush_picker_brushed_picked(mode : E.BrushMode) -> void:
	GridNode.set_brush_mode(mode)


func _on_grid_updated() -> void:
	if $DevButtons.god_mode_enabled():
		GridNode.auto_solve(false, false)
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

func _update_visibilities(new_grid: GridModel) -> void:
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
	var aquariums := new_grid.grid_hints().expected_aquariums
	aquariums.clear()
	var all_sizes := GridNode.grid_logic.all_aquarium_counts()
	for aq_size in AquariumHints.visible_sizes():
		aquariums[aq_size] = all_sizes.get(aq_size, 0)
	

func _get_solution_grid() -> GridModel:
	assert(editor_mode())
	var new_grid := GridImpl.import_data(GridNode.grid_logic.export_data(), GridModel.LoadMode.Solution)
	_update_visibilities(new_grid)
	return new_grid

func _on_playtest_button_pressed() -> void:
	var new_level = Global.create_level(_get_solution_grid(), "")
	TransitionManager.push_scene(new_level)

func maybe_save() -> void:
	if not level_name.is_empty():
		print("Saving the level...")
		if editor_mode():
			# Let's put the visibility info in the grid
			var grid_logic := GridNode.grid_logic
			grid_logic.set_auto_update_hints(false)
			_update_visibilities(grid_logic)
			FileManager.save_editor_level(level_name, null, LevelData.new("", grid_logic.export_data()))
			grid_logic.set_auto_update_hints(true)
		else:
			dummy_save.grid_data = GridNode.grid_logic.export_data()
			dummy_save.mistakes = Counters.mistake.count
			dummy_save.timer_secs = running_time
			FileManager.save_level(level_name, dummy_save)

func reset_level() -> void:
	GridNode.grid_logic.clear_all()
	GridNode.setup(GridNode.grid_logic)
	running_time = 0
	Counters.mistake.set_count(0)
	maybe_save()

func _on_back_button_pressed() -> void:
	maybe_save()
	TransitionManager.pop_scene()


func _on_settings_screen_pause_toggled(active):
	process_game = not active

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_CRASH or what == Node.NOTIFICATION_EXIT_TREE:
		maybe_save()

func _on_autosaver_timeout():
	maybe_save()

func _on_grid_view_updated_size():
	scale_grid()

func _on_dev_buttons_full_solve():
	var r: SolverModel.SolveResult = GridNode.full_solve(true, false)
	var solve_type: String = SolverModel.SolveResult.find_key(r)
	$DevButtons/FullSolveType.text = solve_type


func _on_dev_buttons_use_strategies():
	GridNode.auto_solve(true, false)


func _on_dev_buttons_generate() -> void:
	if not editor_mode():
		return
	var new_grid: GridModel = await $DevButtons.gen_level(GridNode.grid_logic.rows(), GridNode.grid_logic.cols())
	if new_grid != null:
		grid = new_grid
		setup(false)
