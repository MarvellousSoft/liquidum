class_name Level
extends Control

const COUNTER_DELAY_STARTUP = .3
const DESIRED_GRID_W = 1300

@onready var GridNode: GridView = %GridView
@onready var TimerContainer = %TimerContainer
@onready var TimerLabel = %TimerLabel
@onready var CountersPanel = %CountersPanel
@onready var Counters = {
	"water": %WaterCounter,
	"boat": %BoatCounter,
	"mistake": %MistakeCounter,
}
@onready var PlaytestButton = %PlaytestButton
@onready var BrushPicker = %BrushPicker
@onready var AquariumHints: AquariumHintContainer = %AquariumHintContainer
@onready var AnimPlayer = $AnimationPlayer
@onready var DevButtons: DevPanel = $DevButtons
@onready var WaveEffect = %WaveEffect

var update_expected_waters : bool
var update_expected_boats : bool
var process_game := false
var running_time : float
var grid: GridModel = null
var level_name := ""
# TODO: Display this somewhere
var full_name: String
# Has completion data but outdated grid data
var dummy_save := UserLevelSaveData.new({}, 0, 0.0)
var workshop_id := -1

func _ready():
	GridNode.hide()
	await TransitionManager.transition_finished
	GridNode.show()
	setup()
	if workshop_id != -1 and SteamManager.enabled:
		Steam.startPlaytimeTracking([workshop_id])


func _enter_tree():
	%PlaytestButton.visible = false
	if GridNode:
		scale_grid()


func _exit_tree() -> void:
	if workshop_id != -1 and SteamManager.enabled:
		Steam.stopPlaytimeTracking([workshop_id])


func _process(dt):
	if process_game and not grid.editor_mode():
		running_time += dt
		update_timer_label()


func _input(event):
	#TODO: Remove or make it harder on release
	if event.is_action_pressed("debug_1"):
		win()


func setup(try_load := true) -> void:
	DevButtons.setup(grid.editor_mode())
	running_time = 0
	
	var visibility := HintVisibility.default(grid.rows(), grid.cols())
	
	if not level_name.is_empty() and try_load:
		if grid.editor_mode():
			var data := FileManager.load_editor_level(level_name)
			if data != null:
				full_name = data.full_name
				# Load with Testing to get hints then change to editor
				grid = GridExporter.new().load_data(grid, data.grid_data, GridModel.LoadMode.Testing)
				visibility = HintVisibility.from_grid(grid)
				grid.set_auto_update_hints(true)
		else:
			var save := FileManager.load_level(level_name)
			if save != null:
				# Maybe make this validate with original level. Not for now.
				grid = GridExporter.new().load_data(grid, save.grid_data, GridModel.LoadMode.ContentOnly)
				Counters.mistake.set_count(save.mistakes)
				running_time = save.timer_secs
				dummy_save = save
	BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	PlaytestButton.visible = editor_mode()
	if not editor_mode():
		var e_waters = GridNode.get_expected_waters()
		var e_boats = GridNode.get_expected_boats()
		update_expected_waters = e_waters > 0
		update_expected_boats = e_boats > 0
		Counters.water.visible = e_waters != -1
		Counters.boat.visible = e_boats != -1
		CountersPanel.visible = Counters.water.visible or Counters.boat.visible
		if e_boats == -1:
			BrushPicker.disable()
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
	_apply_visibility(visibility)

	
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
	GridNode.setup_cell_corners()


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
	running_time = false
	GridNode.disable()
	AudioManager.play_sfx("win_level")
	WaveEffect.play()
	if Profile.get_option("highlight_grid"):
		GridNode.remove_all_highlights()
	dummy_save.save_completion(Counters.mistake.count, running_time)
	maybe_save(true)
	
	await get_tree().create_timer(1.5).timeout
	
	TransitionManager.pop_scene()
	
	


func _on_brush_picker_brushed_picked(mode : E.BrushMode) -> void:
	GridNode.set_brush_mode(mode)


func _on_grid_updated() -> void:
	if DevButtons.god_mode_enabled():
		GridNode.apply_strategies(DevButtons.selected_strategies(), false, false)
	update_counters()
	if GridNode.is_level_finished() and not editor_mode():
		win()


class HintVisibility:
	var total_water: bool = false
	var total_boats: bool = false
	var expected_aquariums: Array[float] = []
	var row: Array[int]
	var col: Array[int]
	static func default(n: int, m: int) -> HintVisibility:
		var h := HintVisibility.new()
		for i in n:
			h.row.append(HintBar.WATER_COUNT_VISIBLE)
		for j in m:
			h.col.append(HintBar.WATER_COUNT_VISIBLE)
		return h
	static func from_grid(grid: GridModel) -> HintVisibility:
		var h := HintVisibility.new()
		h.total_water = (grid.grid_hints().total_water != -1.)
		h.total_boats = (grid.grid_hints().total_boats != -1)
		h.expected_aquariums.assign(grid.grid_hints().expected_aquariums.keys())
		h.row.assign(grid.row_hints().map(HintVisibility._hint_to_flag))
		h.col.assign(grid.col_hints().map(HintVisibility._hint_to_flag))
		return h
	static func _hint_to_flag(hint: GridModel.LineHint) -> int:
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
	func _update_line_hint(line_hint: GridModel.LineHint, flags: int) -> void:
		if not (flags & HintBar.BOAT_COUNT_VISIBLE):
			line_hint.boat_count = -1
		if not (flags & HintBar.BOAT_TYPE_VISIBLE):
			line_hint.boat_count_type = E.HintType.Any
		if not (flags & HintBar.WATER_COUNT_VISIBLE):
			line_hint.water_count = -1.0
		if not (flags & HintBar.WATER_TYPE_VISIBLE):
			line_hint.water_count_type = E.HintType.Any
	func apply_to_grid(grid: GridModel) -> void:
		var ghints := grid.grid_hints()
		if not total_water:
			ghints.total_water = -1
		if not total_boats:
			ghints.total_boats = -1
		var all_aqs := grid.all_aquarium_counts()
		ghints.expected_aquariums.clear()
		for aq in expected_aquariums:
			ghints.expected_aquariums[aq] = all_aqs.get(aq, 0)
		for i in grid.rows():
			_update_line_hint(grid.row_hints()[i], row[i])
		for j in grid.cols():
			_update_line_hint(grid.col_hints()[j], col[j])


func _apply_visibility(h: HintVisibility) -> void:
	if not editor_mode():
		return
	Counters.water.set_should_be_visible(h.total_water)
	Counters.boat.set_should_be_visible(h.total_boats)
	var aqs := {}
	for aq in h.expected_aquariums:
		aqs[aq] = true
	AquariumHints.set_should_be_visible(aqs)
	GridNode.set_counters_visibility(h.row, h.col)


func _hint_visibility() -> HintVisibility:
	var h := HintVisibility.new()
	h.total_water = Counters.water.should_be_visible()
	h.total_boats = Counters.boat.should_be_visible()
	h.expected_aquariums = AquariumHints.visible_sizes()
	h.row = GridNode.row_hints_should_be_visible()
	h.col = GridNode.col_hints_should_be_visible()
	return h


func _update_visibilities(new_grid: GridModel) -> void:
	_hint_visibility().apply_to_grid(new_grid)


func _get_solution_grid() -> GridModel:
	assert(editor_mode())
	var new_grid := GridImpl.import_data(GridNode.grid_logic.export_data(), GridModel.LoadMode.Solution)
	_update_visibilities(new_grid)
	return new_grid


func _on_playtest_button_pressed() -> void:
	var new_level = Global.create_level(_get_solution_grid(), "", full_name)
	TransitionManager.push_scene(new_level)


func maybe_save(delete_solution := false) -> void:
	if not level_name.is_empty():
		if editor_mode():
			# Let's put the visibility info in the grid
			var grid_logic := GridNode.grid_logic
			grid_logic.set_auto_update_hints(false)
			_update_visibilities(grid_logic)
			FileManager.save_editor_level(level_name, null, LevelData.new(full_name, grid_logic.export_data()))
			grid_logic.set_auto_update_hints(true)
		else:
			if delete_solution:
				grid.clear_content()
			dummy_save.grid_data = GridNode.grid_logic.export_data()
			dummy_save.mistakes = Counters.mistake.count
			dummy_save.timer_secs = running_time
			FileManager.save_level(level_name, dummy_save)


func reset_level() -> void:
	if ConfirmationScreen.start_confirmation("CONFIRM_RESET_LEVEL"):
		if not await ConfirmationScreen.pressed:
			return
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
	var r: SolverModel.SolveResult = GridNode.full_solve(DevButtons.selected_strategies(), true, false)
	DevButtons.set_solve_type(r)


func _on_dev_buttons_use_strategies():
	GridNode.apply_strategies(DevButtons.selected_strategies(), true, false)

func _on_dev_buttons_generate() -> void:
	if not editor_mode():
		return
	var new_grid: GridModel = await DevButtons.gen_level(GridNode.grid_logic.rows(), GridNode.grid_logic.cols(), _hint_visibility())
	if new_grid != null:
		grid = new_grid
		GridNode.grid_logic = grid
		GridNode.update()


func _on_dev_buttons_randomize_water():
	if editor_mode():
		Generator.randomize_water(GridNode.grid_logic)
		GridNode.update()


func _on_dev_buttons_check_interesting():
	var g2 := GridImpl.import_data(GridNode.grid_logic.export_data(), GridModel.LoadMode.Testing)
	g2.clear_content()
	_update_visibilities(g2)
	$DevButtons.do_check_interesting(g2)


func _on_dev_buttons_load_grid(g: GridModel) -> void:
	grid = g
	GridNode.grid_logic = g
	GridNode.update()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_center_container_mouse_entered():
	if Profile.get_option("highlight_grid"):
		GridNode.remove_all_highlights()
