class_name Level
extends Control

const COUNTER_DELAY_STARTUP = .3
const DESIRED_GRID_W = {
	"desktop": 1300,
	"mobile": 700,
}

signal won(info: WinInfo)
signal had_first_win

class WinInfo:
	var first_win: bool
	var mistakes: int
	var time_secs: float
	func _init(first_win_: bool, mistakes_: int, time_secs_: float) -> void:
		first_win = first_win_
		mistakes = mistakes_
		time_secs = time_secs_

@onready var GridNode: GridView = %GridView
@onready var TimerContainer = %TimerContainer
@onready var TimerLabel = %TimerLabel
@onready var CountersPanel = %CountersPanel
@onready var Counters = {
	"water": %WaterCounter,
	"boat": %BoatCounter,
	"mistake": %MistakeCounter,
}
@onready var BrushPicker = %BrushPicker
@onready var AquariumHints: AquariumHintContainer = %AquariumHintContainer
@onready var AnimPlayer = $AnimationPlayer
@onready var WaveEffect = %WaveEffect
@onready var ResetButton: TextureButton = %ResetButton
@onready var BackButton = %BackButton
@onready var Settings = $SettingsScreen
@onready var ContinueAnim = %ContinueAnim
@onready var Description: Label = $Description/Scroll/Label
@onready var DescriptionScroll: ScrollContainer = $Description/Scroll
@onready var TitleBanner: PanelContainer = $Title/TitleBanner
@onready var TitleLabel: Label = $Title/TitleBanner/Label
@onready var LevelLabel: Label = %LevelLabel
@onready var TitleEdit: LineEdit = $Title/Edit

var update_expected_waters : bool
var update_expected_boats : bool
var process_game := false
var running_time : float
var grid: GridModel = null
var level_name := ""
var level_number := -1
var section_number := -1
var full_name: String
var description: String
# Has completion data but outdated grid data
var dummy_save := UserLevelSaveData.new({}, true, 0, 0.0)
var workshop_id := -1
var game_won := false
var reset_text := &"CONFIRM_RESET_LEVEL"
var won_before := false
var reset_mistakes_on_empty := true
var reset_mistakes_on_reset := true
var solve_thread: Thread =  null
var last_saved: int
var last_saved_ago: int = -1

func _ready():
	Global.dev_mode_toggled.connect(_on_dev_mode_toggled)
	if not Global.is_mobile:
		%DevContainer.visible = Global.is_dev_mode()
		%PlaytestButton.visible = false
		%UniquenessCheck.visible = false
	set_level_names_and_descriptions()
	if not Global.is_mobile:
		reset_tutorial()
	if is_campaign_level():
		var data = FileManager.load_level_data(section_number, level_number)
		if not data.tutorial.is_empty():
			if not Global.is_mobile:
				%TutorialContainer.show()
				add_tutorial(data.tutorial)
		else:
			if not Global.is_mobile:
				%TutorialContainer.hide()
	else:
		if not Global.is_mobile:
			%TutorialContainer.hide()
	
	GridNode.hide()
	await TransitionManager.transition_finished
	GridNode.show()
	setup()
	if workshop_id != -1 and SteamManager.enabled:
		SteamManager.steam.startPlaytimeTracking([workshop_id])


func _enter_tree():
	if GridNode:
		scale_grid()
		if not Global.is_mobile:
			%PlaytestButton.visible = editor_mode()
			%UniquenessCheck.visible = editor_mode() and not Global.is_dev_mode()
			%LastSaved.visible = editor_mode()


func _exit_tree() -> void:
	if workshop_id != -1 and SteamManager.enabled:
		SteamManager.steam.stopPlaytimeTracking([workshop_id])
	# Cancel solve if it still exists
	if not Global.is_mobile and %CancelUniqCheck != null:
		%CancelUniqCheck.button_pressed = true

func update_last_saved() -> void:
	var new_last_saved_ago := (Time.get_ticks_msec() - last_saved) / 1000
	if last_saved_ago != new_last_saved_ago:
		last_saved_ago = new_last_saved_ago
		%LastSaved/Time.text = " %ds " % [last_saved_ago]

func _process(dt):
	if grid.editor_mode():
		update_last_saved()
	if process_game and not grid.editor_mode():
		running_time += dt
		update_timer_label()
	Global.alpha_fade_node(dt, %TutorialDisplayBG, %TutorialDisplay.is_active(), 4.0, true)


func _input(event):
	#TODO: Remove or make it harder on release
	if event.is_action_pressed("debug_1"):
		win()

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_CRASH or what == Node.NOTIFICATION_EXIT_TREE:
		maybe_save()
	elif what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		Settings.toggle_pause()


func _unhandled_input(event):
	if event.is_action_pressed("return"):
		Settings.toggle_pause()


func setup(try_load := true) -> void:
	if not grid.editor_mode():
		grid.prettify_hints()
	if not Global.is_mobile:
		%DevButtons.setup(grid.editor_mode())
	running_time = 0
	game_won = false
	last_saved = Time.get_ticks_msec()
	
	var visibility := HintVisibility.default(grid.rows(), grid.cols())
	
	if not level_name.is_empty() and try_load:
		if grid.editor_mode():
			var data := FileManager.load_editor_level(level_name)
			if data != null:
				$Description/Edit.text = data.description
				description = data.description
				TitleEdit.text = data.full_name
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
				update_timer_label()
				dummy_save = save
	BrushPicker.setup(grid.editor_mode())
	GridNode.setup(grid)
	DescriptionScroll.visible = not editor_mode()
	if not Global.is_mobile:
		%PlaytestButton.visible = editor_mode()
		%UniquenessCheck.visible = editor_mode() and not Global.is_dev_mode()
		$Description/Edit.visible = editor_mode()
		%LastSaved.visible = editor_mode()
	TitleEdit.visible = editor_mode()
	TitleBanner.visible = not editor_mode() and full_name != ""
	if not editor_mode():
		var e_waters = GridNode.get_expected_waters()
		var e_boats = GridNode.get_expected_boats()
		update_expected_waters = e_waters > 0
		update_expected_boats = e_boats > 0
		Counters.water.visible = e_waters != -1
		Counters.boat.visible = e_boats > 0
		CountersPanel.visible = Counters.water.visible or Counters.boat.visible
		var no_boat_hint := func(h: GridModel.LineHint) -> bool: return h.boat_count <= 0 and (h.boat_count_type == E.HintType.Hidden or h.boat_count_type == E.HintType.Zero)
		if e_boats <= 0 and grid.row_hints().all(no_boat_hint) and grid.col_hints().all(no_boat_hint):
			BrushPicker.disable_brush(E.BrushMode.Boat)
			BrushPicker.disable_brush(E.BrushMode.NoBoat)
		if is_campaign_level():
			if section_number == 1 and level_number == 1:
				BrushPicker.hide()
	else:
		Counters.water.visible = true
		Counters.boat.visible = true
		update_expected_waters = true
		update_expected_boats = true
		Counters.water.enable_editor()
		Counters.boat.enable_editor()
		Counters.mistake.hide()
		TimerContainer.hide()
	update_counters()
	
	%LevelLabel.visible = not grid.editor_mode()
	%TutorialButton.visible = not grid.editor_mode()
	
	var delay = COUNTER_DELAY_STARTUP
	for counter in Counters.values():
		counter.startup(delay)
		delay += COUNTER_DELAY_STARTUP
	AquariumHints.startup(delay, grid.grid_hints().expected_aquariums, grid.all_aquarium_counts(), GridNode.editor_mode)
	
	AnimPlayer.play("startup")
	
	_apply_visibility(visibility)

	
	AudioManager.play_sfx("start_level")
	
	scale_grid()
	
	await get_tree().create_timer(GridNode.get_grid_delay(grid.rows(), grid.cols())).timeout
	
	process_game = true


func set_level_names_and_descriptions():
	Description.text = description
	if not Global.is_mobile:
		$Description/Edit.text = description
	TitleLabel.text = full_name
	Settings.set_level_name(full_name, section_number, level_number)
	TitleEdit.text = full_name
	LevelLabel.text = tr(full_name)
	if section_number != -1 and level_number != -1:
		%SectionNumber.text = "%d - %d" % [section_number, level_number]
	else:
		%SectionNumber.text = ""


func is_campaign_level():
	return level_number != -1 and section_number != -1


func editor_mode() -> bool:
	return GridNode.editor_mode


func scale_grid() -> void:
	var prev_a = GridNode.modulate.a
	GridNode.modulate.a = 0.0
	
	await get_tree().process_frame
	
	var g_size = GridNode.get_grid_size()
	var w = DESIRED_GRID_W.desktop if not Global.is_mobile else DESIRED_GRID_W.mobile
	var s = min( w / g_size.x, w / g_size.y )
	GridNode.scale = Vector2(s, s)
	GridNode.modulate.a = prev_a
	GridNode.setup_cell_corners()


func reset_tutorial():
	for child in %TutorialCenterContainer.get_children():
		%TutorialCenterContainer.remove_child(child)


func add_tutorial(tutorial_name):
	%TutorialCenterContainer.add_child(Global.get_tutorial(tutorial_name))


func update_counters() -> void:
	if update_expected_waters:
		Counters.water.set_count(GridNode.get_expected_waters() if GridNode.editor_mode else GridNode.get_missing_waters())
	if update_expected_boats:
		Counters.boat.set_count(GridNode.get_expected_boats() if GridNode.editor_mode else GridNode.get_missing_boats())
	AquariumHints.update_values(GridNode.grid_logic.grid_hints().expected_aquariums, GridNode.grid_logic.all_aquarium_counts(), GridNode.editor_mode)

static func time_str(secs: int) -> String:
	var hours = secs / 3600
	var minutes = secs % 3600 / 60
	var seconds = secs % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	else:
		return "%02d:%02d" % [minutes, seconds]

func _timer_str() -> String:
	return Level.time_str(int(running_time))

func update_timer_label() -> void:
	TimerLabel.text = _timer_str()


func maybe_save(delete_solution := false) -> void:
	if game_won and not delete_solution:
		# Already saved
		return
	if not level_name.is_empty():
		if editor_mode():
			# Let's put the visibility info in the grid
			var grid_logic := GridNode.grid_logic
			grid_logic.set_auto_update_hints(false)
			_update_visibilities(grid_logic)
			FileManager.save_editor_level(level_name, null, LevelData.new(full_name, description, grid_logic.export_data(), ""))
			last_saved = Time.get_ticks_msec()
			grid_logic.set_auto_update_hints(true)
		else:
			if delete_solution:
				if level_name == RandomHub.RANDOM:
					FileManager.clear_level(level_name)
					return
				grid.clear_content()
			var is_empty := grid.is_empty()
			dummy_save.is_empty = is_empty
			if is_empty and reset_mistakes_on_empty:
				dummy_save.mistakes = 0
				dummy_save.timer_secs = 0.0
			else:
				dummy_save.mistakes = Counters.mistake.count
				dummy_save.timer_secs = running_time
			dummy_save.grid_data = GridNode.grid_logic.export_data()
			FileManager.save_level(level_name, dummy_save)
			last_saved = Time.get_ticks_msec()


func add_playtime_tracking(stats: Array[String]) -> void:
	stats.append("total")
	$SteamPlaytimeTracker.stats = stats


func reset_level() -> void:
	if ConfirmationScreen.start_confirmation(reset_text):
		if not await ConfirmationScreen.pressed:
			return
	GridNode.grid_logic.clear_all()
	GridNode.setup(GridNode.grid_logic)
	if reset_mistakes_on_reset:
		running_time = 0
		Counters.mistake.set_count(0)
	maybe_save()


func win() -> void:
	if game_won:
		return
	
	game_won = true
	process_game = false
	

	GridNode.remove_all_highlights()
	GridNode.remove_all_preview()
	GridNode.disable()
	ResetButton.disabled = true
	var tween := create_tween()
	tween.tween_property(ResetButton, "modulate:a", 0.5, 1)
	BackButton.disabled = true
	%TutorialButton.disabled = true
	Settings.disable_button()
	
	AudioManager.play_sfx("win_level")
	WaveEffect.play()
	
	won_before = dummy_save.is_completed()
	dummy_save.save_completion(Counters.mistake.count, running_time)
	maybe_save(true)
	won.emit(WinInfo.new(not won_before, int(Counters.mistake.count), running_time))
	
	await get_tree().create_timer(1.5).timeout
	
	ContinueAnim.play("show")


func _on_brush_picker_brushed_picked(mode : E.BrushMode) -> void:
	GridNode.set_brush_mode(mode)
	GridNode.remove_all_preview()


func _on_grid_updated() -> void:
	if not Global.is_mobile and %DevButtons.god_mode_enabled():
		GridNode.apply_strategies(%DevButtons.selected_strategies(), false, false)
	update_counters()
	if not editor_mode() and GridNode.is_level_finished():
		win()

# In hindsight, this was a mistake. We should always store hint visibility in the grid, and load
# it in the UI from there. This way, undos would Just Work™ and things would be stored in the
# model as they should.
class HintVisibility:
	var total_water: bool = false
	var total_boats: bool = true
	var expected_aquariums: Array[float] = []
	var row: Array[int]
	var col: Array[int]
	static func default(n: int, m: int, start := HintBar.WATER_COUNT_VISIBLE) -> HintVisibility:
		var h := HintVisibility.new()
		for i in n:
			h.row.append(start)
		for j in m:
			h.col.append(start)
		return h
	static func all_hidden(n: int, m: int) -> HintVisibility:
		return HintVisibility.default(n, m, 0)
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
		if hint.water_count_type != E.HintType.Hidden:
			val |= HintBar.WATER_TYPE_VISIBLE
		if hint.boat_count != -1:
			val |= HintBar.BOAT_COUNT_VISIBLE
		if hint.boat_count_type != E.HintType.Hidden:
			val |= HintBar.BOAT_TYPE_VISIBLE
		return val
	func _update_line_hint(line_hint: GridModel.LineHint, flags: int) -> void:
		if not (flags & HintBar.BOAT_COUNT_VISIBLE):
			line_hint.boat_count = -1
		if not (flags & HintBar.BOAT_TYPE_VISIBLE) or line_hint.boat_count_type == E.HintType.Zero:
			line_hint.boat_count_type = E.HintType.Hidden
		if not (flags & HintBar.WATER_COUNT_VISIBLE):
			line_hint.water_count = -1.0
		if not (flags & HintBar.WATER_TYPE_VISIBLE) or line_hint.water_count_type == E.HintType.Zero:
			line_hint.water_count_type = E.HintType.Hidden
	func apply_to_grid(grid: GridModel) -> void:
		var ghints := grid.grid_hints()
		var prev_boats := ghints.total_boats
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
		# Let's force boat amount if it would create schrodinger boats
		if grid.any_schrodinger_boats():
			ghints.total_boats = prev_boats
		grid.validate()


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


func _get_solution_grid(mode := GridModel.LoadMode.SolutionNoClear) -> GridModel:
	assert(editor_mode())
	var new_grid := GridImpl.import_data(GridNode.grid_logic.export_data(), mode)
	_update_visibilities(new_grid)
	new_grid.clear_content()
	return new_grid


func _on_playtest_button_pressed() -> void:
	var new_level = Global.create_level(_get_solution_grid(), "", full_name, description, ["playtest"])
	TransitionManager.push_scene(new_level)


func _on_back_button_pressed() -> void:
	maybe_save()
	TransitionManager.pop_scene()


func _on_settings_screen_pause_toggled(paused: bool) -> void:
	process_game = not paused
	$SteamPlaytimeTracker.set_tracking(not paused)


func _on_autosaver_timeout():
	maybe_save()


func _on_grid_view_updated_size():
	scale_grid()


func _on_dev_buttons_full_solve():
	if editor_mode():
		var g2 := _get_solution_grid(GridModel.LoadMode.Testing)
		%DevButtons.start_solve(g2)
	else:
		var r: SolverModel.SolveResult = GridNode.full_solve(%DevButtons.selected_strategies(), true, false)
		%DevButtons.set_solve_type(r)


func _on_dev_buttons_use_strategies():
	GridNode.apply_strategies(%DevButtons.selected_strategies(), true, false)


func _on_dev_buttons_generate() -> void:
	if not editor_mode():
		return
	if %DevButtons.should_reset_visible_aquariums():
		AquariumHints.set_should_be_visible({})
	var new_grid: GridModel = await %DevButtons.gen_level(GridNode.grid_logic.rows(), GridNode.grid_logic.cols(), _hint_visibility())
	if new_grid != null:
		assert(new_grid.editor_mode())
		var vis := HintVisibility.from_grid(new_grid)
		grid = new_grid
		GridNode.grid_logic = grid
		grid.set_auto_update_hints(true)
		GridNode.update(true, true)
		_apply_visibility(vis)


func _on_dev_buttons_randomize_water() -> void:
	if editor_mode():
		GridNode.grid_logic.clear_content()
		Generator.builder().with_diags().build(randi()).randomize_water(GridNode.grid_logic)
		GridNode.update()


func _on_dev_buttons_load_grid(g: GridModel) -> void:
	grid = g
	var visibility := HintVisibility.from_grid(g)
	grid.maybe_update_hints()
	GridNode.grid_logic = g
	GridNode.update()
	_apply_visibility(visibility)
	scale_grid()


func _on_button_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")


func _on_center_container_mouse_entered() -> void:
	GridNode.remove_all_highlights()
	GridNode.remove_all_preview()


func _hint(w_co: float, w_ty: float, b_co: float, b_ty: float, col: bool) -> int:
	var val := 0
	if randf() < w_co:
		val |= HintBar.WATER_COUNT_VISIBLE
	if randf() < w_ty:
		val |= HintBar.WATER_TYPE_VISIBLE
	if randf() < b_co:
		val |= HintBar.BOAT_COUNT_VISIBLE
	if not col and randf() < b_ty:
		val |= HintBar.BOAT_TYPE_VISIBLE
	return val


func _on_dev_buttons_randomize_visibility() -> void:
	var visibility := HintVisibility.default(grid.rows(), grid.cols())
	visibility.total_boats = randf() < .5
	visibility.total_water = randf() < .5
	var w_co := sqrt(randf())
	var w_ty := randf()
	var b_co := sqrt(randf())
	var b_ty := randf()
	for i in grid.rows():
		visibility.row[i] = _hint(w_co, w_ty, b_co, b_ty, false)
	for j in grid.cols():
		visibility.col[j] = _hint(w_co, w_ty, b_co, b_ty, true)
	var aq_pct := randf()
	for aq in grid.all_aquarium_counts():
		if randf() < aq_pct:
			visibility.expected_aquariums.append(aq)
	_apply_visibility(visibility)


func _on_dev_buttons_save():
	var g := GridNode.grid_logic
	if editor_mode():
		g.set_auto_update_hints(false)
		_hint_visibility().apply_to_grid(g)
	else:
		assert(g.are_hints_satisfied())
	FileManager._save_json_data("res://", "%s.json" % level_name, LevelData.new(full_name, description, g.export_data(), "").get_data())
	if editor_mode():
		g.set_auto_update_hints(true)


func _on_continue_button_pressed() -> void:
	if not won_before:
		had_first_win.emit()
		# First time winning all levels
		if LevelLister.all_campaign_levels_completed():
			TransitionManager.change_scene(Global.load_no_mobile("res://game/credits/AllLevelsCompleted").instantiate())
			return
	TransitionManager.pop_scene()


func _on_description_edit_text_changed() -> void:
	if not editor_mode():
		return
	description = $Description/Edit.text


func _on_edit_text_changed(new_text: String) -> void:
	if not editor_mode():
		return
	if new_text.length() <= 0:
		full_name = "AAA"
		return
	full_name = new_text


func _on_dev_mode_toggled(status):
	if not Global.is_mobile:
		%DevContainer.visible = status
		%UniquenessCheck.visible = not status and editor_mode()
		if has_node("LeaderboardDisplay"):
			$LeaderboardDisplay.visible = not status


func _on_dev_buttons_copy_to_editor():
	%DevButtons.do_copy_to_editor(GridNode.grid_logic, _hint_visibility())


func _on_tutorial_button_pressed():
	%TutorialDisplay.enable()

static func check_uniqueness_inner(copied_grid: GridModel, cancel: Callable) -> SolverModel.SolveResult:
	return SolverModel.new().full_solve(copied_grid, SolverModel.STRATEGY_LIST.keys(), cancel)

static func solve_result_to_uniqueness(r: SolverModel.SolveResult) -> String:
	match r:
		SolverModel.SolveResult.SolvedUniqueNoGuess, SolverModel.SolveResult.SolvedUnique:
			return "YES"
		SolverModel.SolveResult.SolvedMultiple:
			return "NO"
		_:
			if r != SolverModel.SolveResult.GaveUp:
				push_error("It shouldn't be unsolvable")
			return "UNIQUE_TOO_HARD"


func check_uniqueness() -> void:
	%CheckUniqueness.disabled = true
	%CancelUniqCheck.disabled = false
	%CancelUniqCheck.button_pressed = false
	%UniqResult.visible = false
	%UniqResult.tooltip_text = ""
	%UniqOngoing.visible = true
	var copied_grid := _get_solution_grid(GridModel.LoadMode.Testing)
	# Need to store in a variable because threads
	var cancel_but: Button = %CancelUniqCheck
	solve_thread.start(Level.check_uniqueness_inner.bind(copied_grid, func(): return cancel_but.button_pressed))
	var r: SolverModel.SolveResult = await Global.wait_for_thread(solve_thread)
	%UniqResult.text = Level.solve_result_to_uniqueness(r)

	%UniqOngoing.visible = false
	%UniqResult.visible = true
	%CancelUniqCheck.disabled = true
	%CheckUniqueness.disabled = false

func _on_check_uniqueness_pressed() -> void:
	if solve_thread == null:
		solve_thread = Thread.new()
	if solve_thread.is_started():
		return
	await check_uniqueness()

const WEEKDAY_EMOJI := ["🐟", "💧", "⛵", "〽️", "❓", "💦", "1️⃣"]

func _on_share_button_pressed() -> void:
	var mistake_str: String
	if Counters.mistake.count == 0:
		mistake_str = "🏆 0 %s" % tr("MISTAKES")
	else:
		mistake_str = "❌ %d %s" % [
			int(Counters.mistake.count),
			tr("MISTAKES" if Counters.mistake.count > 1 else "MISTAKE")
		]

	var weekday: int = Time.get_datetime_dict_from_unix_time(DailyButton._unixtime_ok_timezone()).weekday
	var text := "%s %s\n\n%s %s\n🕑 %s\n%s" % [
		tr("SHARE_TEXT"), DailyButton._today(),
		WEEKDAY_EMOJI[weekday], tr("%s_LEVEL" % DailyButton.DAY_STR[weekday]),
		_timer_str(),
		mistake_str,
	]
	DisplayServer.clipboard_set(text)
	%ShareButton.disabled = true
	%ShareButton.text = "COPIED_TO_CLIPBOARD"
