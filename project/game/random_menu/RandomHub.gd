class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Difficulties/VBox/Continue
@onready var ContinueSeparator: HSeparator = $Difficulties/VBox/ContinueSeparator
@onready var Completed: VBoxContainer = %CompletedCount

var gen := RandomLevelGenerator.new()

# Do not change the model difficulty names, at most the user displayed ones
enum Difficulty { Easy = 0, Medium, Hard, Expert, Insane }

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
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
		var button: Button = $Difficulties/VBox.get_node(dif_name.capitalize())
		var open := CampaignLevelLister.section_complete(difs[dif] - 1)
		if dif == "insane":
			open = open and CampaignLevelLister.all_campaign_levels_completed()
		open = open or Global.is_dev_mode() or Profile.get_option("unlock_everything")
		if dif == "insane" and Global.is_mobile:
			%UnlockText.visible = not open
		if open:
			button.tooltip_text = "%s_TOOLTIP" % dif_name.to_upper()
		else:
			button.disabled = true
			button.tooltip_text = "%s_TOOLTIP_DISABLED" % dif_name.to_upper()
	
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
	get_tree().reload_current_scene()


func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_unlock_changed)
	Profile.unlock_everything_changed.connect(_on_unlock_changed)
	
	GeneratingLevel.cancel.connect(_on_cancel_gen_pressed)
	call_deferred(&"_update")


func _exit_tree() -> void:
	Profile.unlock_everything_changed.disconnect(_on_unlock_changed)
	Global.dev_mode_toggled.disconnect(_on_unlock_changed)
	GeneratingLevel.cancel.disconnect(_on_cancel_gen_pressed)

func _dif_name(dif: Difficulty, marathon_left: int, marathon_total: int) -> String:
	var dif_name := tr("%s_BUTTON" % Difficulty.find_key(dif).to_upper())
	if marathon_left != -1:
		dif_name += " (%d⁄%d)" % [marathon_total - marathon_left, marathon_total]
	return dif_name

func _update() -> void:
	var has_random_level := (FileManager.load_level(RANDOM) != null and FileManager.load_random_level() != null)
	Continue.visible = has_random_level
	ContinueSeparator.visible = has_random_level and not Global.is_mobile
	if has_random_level:
		var data := FileManager.load_random_level()
		Continue.text = "%s - %s" % [tr("CONTINUE"), _dif_name(data.difficulty, data.marathon_left, data.marathon_total)]
	for dif in Difficulty:
		var but: Button = $Difficulties/VBox.get_node(dif)
		if not but.disabled and has_node("%Marathon"):
			var dif_tr := "%s_BUTTON" % [dif.to_upper()]
			var val: int = int(%Marathon/Slider.value)
			if val > 1:
				but.text = _dif_name(Difficulty[dif], val, val)
			else:
				but.text = dif_tr
		var cont: Node = Completed.get_node(dif)
		cont.visible = not but.disabled
		cont.get_node(^"HBox/Count").text = "%d" % UserData.current().random_levels_completed[Difficulty[dif]]


func _play_new_level_again():
	assert(Global.play_new_dif_again != -1)
	if Global.play_new_dif_again != -1:
		if not Global.is_mobile:
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
			return await l_gen.generate(rng, 5, 5, RandomHub._easy_visibility, RandomHub._nothing, ["BasicRow", "BasicCol"], [])
		Difficulty.Medium:
			return await l_gen.generate(rng, 6, 6, RandomHub._medium_visibility, RandomHub._nothing, ["BasicCol", "BasicRow", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic"], ["MediumCol", "MediumRow", "FullPropagateNoWater"])
		Difficulty.Hard:
			return await l_gen.generate(rng, 5, 4, RandomHub._hard_visibility, RandomHub._diags, ["BasicCol", "BasicRow", "FullPropagateNoWater", "MediumCol", "MediumRow", "AllWatersEasy", "BoatRow"], ["TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "BoatCol", "AllBoats", "AllWatersMedium"])
		Difficulty.Expert:
			return await l_gen.generate(rng, 5, 5, RandomHub._expert_visibility, RandomHub._expert_options, ["BasicCol", "BasicRow", "FullPropagateNoWater", "MediumCol", "MediumRow", "BoatRow", "BoatCol", "AllWatersEasy", "AllWatersMedium", "AllBoats", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "AquariumsBasic"], ["TogetherRowAdvanced", "TogetherColAdvanced", "SeparateRowAdvanced", "SeparateColAdvanced", "AdvancedRow", "AdvancedCol", "AquariumsAdvanced"])
		Difficulty.Insane:
			return await l_gen.generate(rng, 6, 6, RandomHub._expert_visibility, RandomHub._expert_options, SolverModel.STRATEGY_LIST.keys(), [])
		_:
			push_error("Unknown difficulty %d" % dif)
			return null


func continue_marathon(dif: Difficulty, left: int, total: int, seed_str: String, manually_seeded: bool, change_scene: bool, start_time: float, start_mistakes: int) -> void:
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

func gen_and_play(rng: RandomNumberGenerator, dif: Difficulty, seed_str: String, manually_seeded: bool, marathon_left: int, marathon_total: int, marathon_time: float, marathon_mistakes: int) -> void:
	if gen.running():
		return
	GeneratingLevel.enable()
	var g := await RandomHub.gen_from_difficulty(gen, rng, dif)
	GeneratingLevel.disable()
	if g == null:
		return
	# There may be an existing level save
	FileManager.clear_level(RANDOM)
	var data := LevelData.new(_dif_name(dif, marathon_left, marathon_total), "", g.export_data(), "")
	data.difficulty = dif
	data.marathon_left = marathon_left
	data.marathon_total = marathon_total
	data.seed_str = seed_str
	data.manually_seeded = manually_seeded
	FileManager.save_random_level(data)
	load_existing(marathon_time, marathon_mistakes)


func load_existing(marathon_time: float, marathon_mistakes: int) -> void:
	var data := FileManager.load_random_level()
	if data == null:
		return
	var tracking: Array[String] = ["random", "random_%s" % (Difficulty.find_key(data.difficulty) as String).to_lower()]
	if data.marathon_left != -1:
		tracking.append("marathon")
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), RANDOM, data.full_name, "", tracking)
	level.difficulty = data.difficulty
	level.seed_str = data.seed_str
	level.manually_seeded = data.manually_seeded
	if data.marathon_left != -1:
		level.marathon_left = data.marathon_left
		level.marathon_total = data.marathon_total
		level.reset_mistakes_on_empty = false
		level.reset_mistakes_on_reset = false
		level.running_time = marathon_time
		level.initial_mistakes = marathon_mistakes
	level.won.connect(_level_completed.bind(data.difficulty, data.manually_seeded, data.marathon_left, data.marathon_total))
	if Global.play_new_dif_again != -1:
		TransitionManager.change_scene(level)
	else:
		TransitionManager.push_scene(level)


func _confirm_new_level() -> bool:
	AudioManager.play_sfx("button_pressed")
	if Global.play_new_dif_again == -1 and Continue.visible and ConfirmationScreen.start_confirmation(&"CONFIRM_NEW_RANDOM"):
		return await ConfirmationScreen.pressed
	return true


func _level_completed(info: Level.WinInfo, dif: Difficulty, manually_seeded: bool, marathon_left: int, marathon_total: int) -> void:
	# Save was already deleted
	UserData.current().random_levels_completed[dif] += 1
	UserData.save()
	var stats := StatsTracker.instance()
	stats.increment_random_any()
	if dif == Difficulty.Insane and info.first_win and info.mistakes < 3 and not manually_seeded:
		stats.increment_insane_good()
	if marathon_total == 10 and marathon_left == 0:
		if info.mistakes == 0:
			stats.unlock_flawless_marathon(dif)
		const MAX_MINUTES: Array[int] = [3, 5, 9, 11, 20]
		if info.mistakes <= 5 and info.time_secs <= MAX_MINUTES[dif] * 60:
			stats.unlock_fast_marathon(dif)
			


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
static func hide_too_easy_hints(grid: GridModel, rows := true, cols := true) -> void:
	var hints := grid.row_hints()
	if rows:
		for i in grid.rows():
			if hints[i].water_count == grid.cols() or hints[i].water_count == 0:
				hints[i].water_count = -1
	if cols:
		hints = grid.col_hints()
		for j in grid.cols():
			if hints[j].water_count == grid.rows() or hints[j].water_count == 0:
				hints[j].water_count = -1


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


func _on_dif_pressed(dif: Difficulty) -> void:
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
		var data := UserData.current()
		data.random_levels_created[dif] += 1
		var i := data.random_levels_created[dif]
		seed_str = str(i)
		rng.seed = RandomHub.consistent_hash(seed_str)
		UserData.save()
		var success_state := PreprocessedDifficulty.current(dif).success_state(i)
		if success_state != 0:
			rng.state = success_state
	else:
		rng.seed = RandomHub.consistent_hash(seed_str)
	assert(not seed_str.is_empty())
	await gen_and_play(rng, dif, seed_str, manually_seeded, -1, -1, 0, 0)


func _on_cancel_gen_pressed():
	gen.cancel()


func _on_custom_seed_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	$CustomSeedButton.visible = false
	$Seed.visible = true


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
	%PanelContainer.theme = Global.get_font_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")

func _on_marathon_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	%Marathon/Button.hide()
	%Marathon/Slider.value = 10
	%Marathon/Slider.show()
	_update()


func _on_marathon_value_changed(_value: float) -> void:
	_update()
