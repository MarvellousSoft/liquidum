class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Difficulties/VBox/Continue
@onready var ContinueSeparator: HSeparator = $Difficulties/VBox/ContinueSeparator
@onready var Completed: VBoxContainer = %CompletedCount

var gen := RandomLevelGenerator.new()

# Do not change the model difficulty names, at most the user displayed ones
enum Difficulty { Easy = 0, Medium, Hard, Expert, Insane }

func _save_level_name() -> String:
	return RANDOM

func _load_level_data() -> LevelData:
	return FileManager.load_random_level()

func _save_level_data(data: LevelData) -> void:
	FileManager.save_random_level(data)

func _get_modes() -> Array[int]:
	var modes: Array[int] = []
	for dif in Difficulty.values():
		modes.append(dif)
	return modes

func _mode_name(mode: int) -> String:
	return Difficulty.find_key(mode)

func _mode_button_key(mode: int) -> String:
	return "%s_BUTTON" % _mode_name(mode).to_upper()

func _mode_button_text(mode: int) -> String:
	return tr(_mode_button_key(mode))

func _get_mode_button(mode: int) -> Button:
	var name_str := _mode_name(mode)
	if has_node("Difficulties/VBox"):
		return $Difficulties/VBox.get_node_or_null(name_str)
	return null

func _get_completed_node(mode: int) -> Node:
	if Completed == null:
		return null
	return Completed.get_node_or_null(_mode_name(mode))

func _get_completed_count(mode: int) -> int:
	return UserData.current().random_levels_completed[mode]

func _bump_created_count(mode: int) -> int:
	var data := UserData.current()
	data.random_levels_created[mode] += 1
	UserData.save()
	return data.random_levels_created[mode]

func _get_preprocessed_state(mode: int, seed_int: int) -> int:
	return PreprocessedDifficulty.current(mode).success_state(seed_int)

func _confirm_new_text() -> StringName:
	return &"CONFIRM_NEW_RANDOM"

func _get_tracking(data: LevelData) -> Array[String]:
	var tracking: Array[String] = ["random", "random_%s" % _mode_name(data.difficulty).to_lower()]
	if data.marathon_left != -1:
		tracking.append("marathon")
	return tracking

func _generate_grid(rng: RandomNumberGenerator, mode: int, _marathon_left: int, _marathon_total: int, _seed_str: String) -> GridModel:
	return await RandomHub.gen_from_difficulty(gen, rng, mode)

func _setup_level_data(_data: LevelData, _mode: int, _marathon_left: int, _marathon_total: int, _seed_str: String) -> void:
	pass

func _on_level_won(info: Level.WinInfo, level: Level, data: LevelData) -> void:
	_level_completed(info, level, data.difficulty, data.manually_seeded, data.marathon_left, data.marathon_total)

func _ready() -> void:
	%Version.text = "v" + Profile.VERSION
	%Version.visible = Profile.SHOW_VERSION
	
func _back_logic() -> void:
	if $SettingsScreen.active:
		$SettingsScreen.toggle_pause()
	else:
		_on_back_pressed()
	

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_logic()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		_back_logic()

func _on_unlock_changed(_on: bool) -> void:
	_update_unlocked()


func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_unlock_changed)
	Profile.unlock_everything_changed.connect(_on_unlock_changed)
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	
	call_deferred(&"_update_unlocked")


func _exit_tree() -> void:
	Profile.unlock_everything_changed.disconnect(_on_unlock_changed)
	Global.dev_mode_toggled.disconnect(_on_unlock_changed)
	Profile.dark_mode_toggled.disconnect(_on_dark_mode_changed)

func _dif_name(dif: int, marathon_left: int, marathon_total: int) -> String:
	var dif_name := _mode_button_text(dif)
	if marathon_left != -1:
		dif_name += " (%d⁄%d)" % [marathon_total - marathon_left, marathon_total]
	return dif_name

func _update_unlocked() -> void:
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	if has_node("Difficulties/VBox/Easy"):
		$Difficulties/VBox/Easy.tooltip_text = "EASY_TOOLTIP"
	# Unlock difficulty after unlocking this section
	var difs := {
		medium = 2,
		hard = 3,
		expert = 5,
		# Additionally, all campaign levels must be completed
		insane = 7,
	}
	for dif in difs:
		var dif_name: String = dif
		var button: Button = $Difficulties/VBox.get_node_or_null(dif_name.capitalize())
		if button == null:
			continue
		var open := CampaignLevelLister.section_complete(difs[dif] - 1)
		if dif == "insane":
			open = open and CampaignLevelLister.all_campaign_levels_completed()
		open = open or Global.is_dev_mode() or Profile.get_option("unlock_everything")
		open = open and not Global.is_demo
		if dif == "insane" and Global.is_mobile and has_node("%UnlockText"):
			%UnlockText.visible = not open
		button.disabled = not open
		if open:
			button.tooltip_text = "%s_TOOLTIP" % dif_name.to_upper()
		else:
			button.tooltip_text = "%s_TOOLTIP_DISABLED" % dif_name.to_upper()
	_update_contents()

func _update_contents() -> void:
	var has_saved_level := (FileManager.load_level(_save_level_name()) != null and _load_level_data() != null)
	Continue.visible = has_saved_level
	ContinueSeparator.visible = has_saved_level and not Global.is_mobile
	if has_saved_level:
		var data := _load_level_data()
		Continue.text = "%s - %s" % [tr("CONTINUE"), _dif_name(data.difficulty, data.marathon_left, data.marathon_total)]
	for mode in _get_modes():
		var but: Button = _get_mode_button(mode)
		if but != null:
			but.text = _mode_button_text(mode)
			if not but.disabled and has_node("%Marathon"):
				var val: int = int(%Marathon/Slider.value)
				if val > 1:
					but.text = _dif_name(mode, val, val)
		var cont: Node = _get_completed_node(mode)
		if cont != null:
			cont.visible = (but == null or not but.disabled)
			cont.get_node(^"HBox/Count").text = "%d" % _get_completed_count(mode)


func _play_new_level_again():
	assert(Global.play_new_dif_again != -1)
	if Global.play_new_dif_again != -1:
		if not Global.is_mobile and has_node("Seed"):
			$Seed.text = ""
		await _on_dif_pressed(Global.play_new_dif_again)
		Global.play_new_dif_again = -1
	else:
		TransitionManager.pop_scene()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


static func gen_from_difficulty(l_gen: RandomLevelGenerator, rng: RandomNumberGenerator, dif: Difficulty) -> GridModel:
	match dif:
		Difficulty.Easy:
			return await l_gen.generate(rng, 5, 5, RandomHub._easy_visibility, RandomHub._nothing, ["BasicRow", "BasicCol", "CellBasic"], [])
		Difficulty.Medium:
			return await l_gen.generate(rng, 6, 6, RandomHub._medium_visibility, RandomHub._nothing, ["BasicCol", "BasicRow",  "CellBasic", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic"], ["MediumCol", "MediumRow", "FullPropagateNoWater"])
		Difficulty.Hard:
			return await l_gen.generate(rng, 5, 4, RandomHub._hard_visibility, RandomHub._diags, ["BasicCol", "BasicRow",  "CellBasic", "FullPropagateNoWater", "MediumCol", "MediumRow", "AllWatersEasy", "BoatRow"], ["TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "BoatCol", "AllBoats", "AllWatersMedium"])
		Difficulty.Expert:
			return await l_gen.generate(rng, 5, 5, RandomHub._expert_visibility, RandomHub._expert_options, ["BasicCol", "BasicRow",  "CellBasic", "FullPropagateNoWater", "MediumCol", "MediumRow", "BoatRow", "BoatCol", "AllWatersEasy", "AllWatersMedium", "AllBoats", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "AquariumsBasic"], ["TogetherRowAdvanced", "TogetherColAdvanced", "SeparateRowAdvanced", "SeparateColAdvanced", "AdvancedRow", "AdvancedCol", "AquariumsAdvanced"])
		Difficulty.Insane:
			return await l_gen.generate(rng, 6, 6, RandomHub._expert_visibility, RandomHub._expert_options, SolverModel.STRATEGY_LIST.keys(), [])
		_:
			push_error("Unknown difficulty %d" % dif)
			return null


func continue_marathon(dif: int, left: int, total: int, seed_str: String, manually_seeded: bool, change_scene: bool, start_time: float, start_mistakes: int) -> void:
	if left == 0:
		TransitionManager.pop_scene()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash("%s-%d" % [seed_str, left])
	if change_scene:
		# Hack so the following function uses TransitionManager.change_scene
		Global.play_new_dif_again = 0
	await gen_and_play(rng, dif, seed_str, manually_seeded, left - 1, total, start_time, start_mistakes)
	Global.play_new_dif_again = -1

func gen_and_play(rng: RandomNumberGenerator, dif: int, seed_str: String, manually_seeded: bool, marathon_left: int, marathon_total: int, marathon_time: float, marathon_mistakes: int) -> void:
	if gen.running():
		return
	GeneratingLevel.enable()
	var g := await _generate_grid(rng, dif, marathon_left, marathon_total, seed_str)
	GeneratingLevel.disable()
	if g == null:
		if Global.play_new_dif_again != -1:
			TransitionManager.pop_scene()
		return
	# There may be an existing level save
	FileManager.clear_level(_save_level_name())
	var data := LevelData.new(_dif_name(dif, marathon_left, marathon_total), "", g.export_data(), "")
	data.difficulty = dif
	data.marathon_left = marathon_left
	data.marathon_total = marathon_total
	data.seed_str = seed_str
	data.manually_seeded = manually_seeded
	_setup_level_data(data, dif, marathon_left, marathon_total, seed_str)
	_save_level_data(data)
	load_existing(marathon_time, marathon_mistakes)

func _speedrun_key(marathon_total: int, dif: int) -> String:
	const M_10 := ["n2ylrv1d-p85ykw3l.qyzxwj21", "n2ylrv1d-p85ykw3l.ln8yozjl", "n2ylrv1d-p85ykw3l.10v5dw2l", "n2ylrv1d-p85ykw3l.qj7z8x3q", "n2ylrv1d-p85ykw3l.q654ezjl"]
	const M_100 := ["5dw3qq52-p85ykw3l.qyzxwj21", "5dw3qq52-p85ykw3l.ln8yozjl", "5dw3qq52-p85ykw3l.10v5dw2l", "5dw3qq52-p85ykw3l.qj7z8x3q", "5dw3qq52-p85ykw3l.q654ezjl"]
	if dif >= 0 and dif < M_10.size():
		if marathon_total == 10:
			return M_10[dif]
		elif marathon_total == 100:
			return M_100[dif]
	return ""

func load_existing(marathon_time: float, marathon_mistakes: int) -> void:
	var data := _load_level_data()
	if data == null:
		return
	var tracking: Array[String] = _get_tracking(data)
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), _save_level_name(), data.full_name, "", tracking)
	level.difficulty = data.difficulty
	level.seed_str = data.seed_str
	level.manually_seeded = data.manually_seeded
	level.flavor = data.flavor
	level.difficulty_name = data.difficulty_name
	if data.marathon_left != -1:
		level.marathon_left = data.marathon_left
		level.marathon_total = data.marathon_total
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		level.running_time = marathon_time
		level.initial_mistakes = marathon_mistakes
	level.won.connect(_on_level_won.bind(level, data))
	if Global.play_new_dif_again != -1:
		TransitionManager.change_scene(level)
	else:
		TransitionManager.push_scene(level)
	await level.ready
	_setup_level_leaderboard(level, data)

func _setup_level_leaderboard(level: Level, data: LevelData) -> void:
	if SteamManager.enabled and shows_marathon_leaderboards(data.marathon_total, data.manually_seeded):
		var l_id := marathon_leaderboard(data.marathon_total, data.difficulty)
		await StoreIntegrations.leaderboard_create_if_not_exists(l_id, StoreIntegrations.SortMethod.SmallestFirst)
		var l_data := await RecurringMarathon.get_leaderboard_data(l_id)
		if not l_data.is_empty():
			var display := LeaderboardDisplay.get_or_create(level, "MARATHON", false, _speedrun_key(data.marathon_total, data.difficulty))
			var dif_name := _mode_button_text(data.difficulty).to_lower()
			display.display(l_data, "%d %s" % [data.marathon_total, dif_name], [], "")

func _confirm_new_level() -> bool:
	AudioManager.play_sfx("button_pressed")
	if Global.play_new_dif_again == -1 and Continue.visible and ConfirmationScreen.start_confirmation(_confirm_new_text()):
		return await ConfirmationScreen.pressed
	return true

func marathon_leaderboard(marathon_size: int, dif: int) -> String:
	return "%s_marathon_%d" % [_mode_name(dif).to_lower(), marathon_size]

func shows_marathon_leaderboards(marathon_total: int, manually_seeded: bool) -> bool:
	return not manually_seeded and marathon_total >= 5 and marathon_total <= 100 and (marathon_total % 5) == 0

func _level_completed(info: Level.WinInfo, level: Level, dif: int, manually_seeded: bool, marathon_left: int, marathon_total: int) -> void:
	# Save was already deleted
	UserData.current().random_levels_completed[dif] += 1
	UserData.save()
	var stats := StatsTracker.instance()
	stats.increment_random_any()
	if dif == Difficulty.Insane and info.first_win and info.mistakes < 3 and not manually_seeded:
		stats.increment_insane_good()
	if marathon_total == 10 and marathon_left == 0:
		if info.total_marathon_mistakes == 0:
			await stats.unlock_flawless_marathon(dif)
		const MAX_MINUTES: Array[int] = [3, 5, 9, 11, 20]
		if dif >= 0 and dif < MAX_MINUTES.size() and info.total_marathon_mistakes <= 5 and info.time_secs <= MAX_MINUTES[dif] * 60:
			await stats.unlock_fast_marathon(dif)
	if marathon_left == 0 and shows_marathon_leaderboards(marathon_total, manually_seeded):
		await RecurringMarathon.upload_leaderboard(marathon_leaderboard(marathon_total, dif), info, true)
		if SteamManager.enabled:
			var l_id := marathon_leaderboard(marathon_total, dif)
			await StoreIntegrations.leaderboard_create_if_not_exists(l_id, StoreIntegrations.SortMethod.SmallestFirst)
			var l_data := await RecurringMarathon.get_leaderboard_data(l_id)
			if not l_data.is_empty():
				var display := LeaderboardDisplay.get_or_create(level, "MARATHON", false)
				var dif_name := _mode_button_text(dif).to_lower()
				display.display(l_data, "%d %s" % [marathon_total, dif_name], [], "")
		


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	load_existing(0, 0)


static func _vis_array_or(rng: RandomNumberGenerator, a: Array[int], val: int, count: int) -> void:
	var b: Array[int] = []
	for i in a.size():
		b.append(val if i < count else 0)
	Global.shuffle(b, rng)
	for i in a.size():
		a[i] |= b[i]


static func _expert_options(rng: RandomNumberGenerator) -> Generator.Options:
	return Generator.builder().with_diags(rng.randf() < 0.5).with_boats(rng.randf() < 0.35)


static func _diags(rng: RandomNumberGenerator) -> Generator.Options:
	return Generator.builder().with_diags().with_boats(rng.randf() < 0.5)


static func _nothing(_rng: RandomNumberGenerator) -> Generator.Options:
	return Generator.builder()

# If a hint is 0 or the size of row/col, hide it. This makes puzzles more interesting.
# Also hides useless {}
static func hide_too_easy_hints(grid: GridModel, rows := true, cols := true) -> void:
	var has_diags := false
	for i in grid.rows():
		if not has_diags:
			for j in grid.cols():
				if grid.get_cell(i, j).cell_type() != E.CellType.Single:
					has_diags = true
					break
	var hints := grid.row_hints()
	if rows:
		for i in grid.rows():
			if hints[i].water_count == grid.cols() or hints[i].water_count == 0:
				hints[i].water_count = -1
			if (hints[i].water_count == 1 and not has_diags) or hints[i].water_count == grid.cols() or hints[i].water_count == 0.5:
				hints[i].water_count_type = E.HintType.Hidden
	if cols:
		hints = grid.col_hints()
		for j in grid.cols():
			if hints[j].water_count == grid.rows() or hints[j].water_count == 0:
				hints[j].water_count = -1
			if (hints[j].water_count == 1 and not has_diags) or hints[j].water_count == grid.rows() or hints[j].water_count == 0.5:
				hints[j].water_count_type = E.HintType.Hidden


static func _easy_visibility(_rng: RandomNumberGenerator, grid: GridModel) -> void:
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)


static func _medium_visibility(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(3, a.size() + 2), a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size() - 2), 0))
	h.apply_to_grid(grid)
	hide_too_easy_hints(grid)


static func _hard_visibility(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	h.total_water = rng.randf() < 0.3
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(1, a.size() + 3), a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size()), 0))
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() / 2)))
	h.apply_to_grid(grid)
	hide_too_easy_hints(grid)

static func _expert_visibility(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	h.total_water = rng.randf() < 0.3
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(0, a.size()), a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-4, a.size()), 0))
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() / 2)))
	h.apply_to_grid(grid)
	hide_too_easy_hints(grid)
	if rng.randf() < 0.35:
		Generator.randomize_aquarium_hints(rng, grid)

# We're using this to generate seeds from sequential numbers since Godot docs says
# similar seeds might lead to similar values.
static func consistent_hash(x: String) -> int:
	return x.sha1_buffer().decode_s64(0)


func _on_dif_pressed(dif: int) -> void:
	if not await _confirm_new_level():
		return
	var rng := RandomNumberGenerator.new()
	var seed_str: String = $Seed.text if has_node("Seed") else ""
	var marathon := floori(%Marathon/Slider.value if has_node(^"%Marathon") else 1.0)
	var manually_seeded := not seed_str.is_empty()
	if marathon != 1:
		if seed_str.is_empty():
			seed_str = str(randi())
		await continue_marathon(dif, marathon, marathon, seed_str, manually_seeded, false, 0, 0)
		return
	if seed_str.is_empty():
		var i := _bump_created_count(dif)
		seed_str = str(i)
		rng.seed = RandomHub.consistent_hash(seed_str)
		var success_state := _get_preprocessed_state(dif, i)
		if success_state != 0:
			rng.state = success_state
	else:
		rng.seed = RandomHub.consistent_hash(seed_str)
	assert(not seed_str.is_empty())
	await gen_and_play(rng, dif, seed_str, manually_seeded, -1, -1, 0, 0)


func _on_custom_seed_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	$CustomSeedButton.visible = false
	$Seed.visible = true


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
	%PanelContainer.theme = Global.get_font_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_marathon_value_changed(_value: float) -> void:
	_update_contents()


func _on_button_marathon_count_pressed(count: int) -> void:
	if count != %Marathon/Slider.value:
		%Marathon/Slider.value = count
		_update_contents()

func _on_marathon_button_pressed() -> void:
	if has_node("%Marathon/Button"):
		%Marathon/Button.hide()
	if has_node("%Marathon/Slider"):
		%Marathon/Slider.show()

