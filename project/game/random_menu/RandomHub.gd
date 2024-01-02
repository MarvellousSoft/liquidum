class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Difficulties/VBox/Continue
@onready var ContinueSeparator: HSeparator = $Difficulties/VBox/ContinueSeparator
@onready var Completed: VBoxContainer = $CompletedCount

var gen := RandomLevelGenerator.new()

# Do not change the model difficulty names, at most the user displayed ones
enum Difficulty { Easy = 0, Medium, Hard, Expert, Insane }

func _ready() -> void:
	$Seed.visible = Global.is_dev_mode()
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
		var open := LevelLister.section_complete(difs[dif] - 1)
		if dif == "insane":
			open = open and LevelLister.all_campaign_levels_completed()
		if open or Global.is_dev_mode():
			button.tooltip_text = "%s_TOOLTIP" % dif_name.to_upper()
		else:
			button.disabled = true
			button.tooltip_text = "%s_TOOLTIP_DISABLED" % dif_name.to_upper()

func _on_dev_mode(_on: bool) -> void:
	get_tree().reload_current_scene()

func _enter_tree() -> void:
	Global.dev_mode_toggled.connect(_on_dev_mode)
	GeneratingLevel.cancel.connect(_on_cancel_gen_pressed)
	call_deferred(&"_update")

func _exit_tree() -> void:
	Global.dev_mode_toggled.disconnect(_on_dev_mode)
	GeneratingLevel.cancel.disconnect(_on_cancel_gen_pressed)

func _update() -> void:
	var has_random_level := (FileManager.load_level(RANDOM) != null)
	Continue.visible = has_random_level
	ContinueSeparator.visible = has_random_level
	if has_random_level:
		var dif := FileManager.load_random_level().difficulty
		Continue.text = "%s - %s" % [tr("CONTINUE"), tr("%s_BUTTON" % Difficulty.find_key(dif).to_upper())]
	for dif in Difficulty:
		var label: Label = Completed.get_node(dif)
		label.visible = not $Difficulties/VBox.get_node(dif).disabled
		label.text = "%s - %d" % [tr("%s_BUTTON" % dif.to_upper()), UserData.current().random_levels_completed[Difficulty[dif]]]

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.pop_scene()

static func gen_from_difficulty(l_gen: RandomLevelGenerator, rng: RandomNumberGenerator, dif: Difficulty) -> GridModel:
	match dif:
		Difficulty.Easy:
			return await l_gen.generate(rng, 5, 5, RandomHub._easy_visibility, RandomHub._nothing, ["BasicRow", "BasicCol"], [])
		Difficulty.Medium:
			return await l_gen.generate(rng, 6, 6, RandomHub._medium_visibility, RandomHub._nothing, ["BasicCol", "BasicRow", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic"], ["MediumCol", "MediumRow"])
		Difficulty.Hard:
			return await l_gen.generate(rng, 5, 4, RandomHub._hard_visibility, RandomHub._diags, ["BasicCol", "BasicRow", "MediumCol", "MediumRow", "AllWatersEasy", "BoatRow"], ["TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic", "BoatCol", "AllBoats", "AllWatersMedium"])
		Difficulty.Expert:
			return await l_gen.generate(rng, 5, 5, RandomHub._hard_visibility, RandomHub._expert_options, ["BasicCol", "BasicRow", "MediumCol", "MediumRow", "BoatRow", "BoatCol", "AllWatersEasy", "AllWatersMedium", "AllBoats", "TogetherRowBasic", "TogetherColBasic", "SeparateRowBasic", "SeparateColBasic"], ["TogetherRowAdvanced", "TogetherColAdvanced", "SeparateRowAdvanced", "SeparateColAdvanced", "AdvancedRow", "AdvancedCol"])
		Difficulty.Insane:
			return await l_gen.generate(rng, 6, 6, RandomHub._hard_visibility, RandomHub._expert_options, SolverModel.STRATEGY_LIST.keys(), [])
		_:
			push_error("Uknown difficulty %d" % dif)
			return null

func gen_and_play(rng: RandomNumberGenerator, dif: Difficulty) -> void:
	if gen.running():
		return
	GeneratingLevel.enable()
	var g := await RandomHub.gen_from_difficulty(gen, rng, dif)
	GeneratingLevel.disable()
	if g == null:
		return
	# There may be an existing level save
	FileManager.clear_level(RANDOM)
	var data := LevelData.new("", "", g.export_data(), "")
	data.difficulty = dif
	FileManager.save_random_level(data)
	load_existing()

func load_existing() -> void:
	var data := FileManager.load_random_level()
	if data == null:
		return
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), RANDOM, data.full_name, "", ["random", "random_%s" % (Difficulty.find_key(data.difficulty) as String).to_lower()])
	level.won.connect(_level_completed.bind(data.difficulty))
	TransitionManager.push_scene(level)

func _confirm_new_level() -> bool:
	AudioManager.play_sfx("button_pressed")
	if Continue.visible and ConfirmationScreen.start_confirmation(&"CONFIRM_NEW_RANDOM"):
		return await ConfirmationScreen.pressed
	return true

func _level_completed(_info: Level.WinInfo, dif: Difficulty) -> void:
	# Save was already deleted
	UserData.current().random_levels_completed[dif] += 1
	UserData.save()

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	load_existing()

static func _vis_array_or(rng: RandomNumberGenerator, a: Array[int], val: int, count: int) -> void:
	var b: Array[int] = []
	for i in a.size():
		b.append(val if i < count else 0)
	Global.shuffle(b, rng)
	for i in a.size():
		a[i] |= b[i]

static func _expert_options(rng: RandomNumberGenerator) -> int:
	return (1 if rng.randf() < 0.5 else 0) + (2 if rng.randf() < 0.35 else 0)

static func _diags(rng: RandomNumberGenerator) -> int:
	return 1 + (2 if rng.randf() < 0.5 else 0) 

static func _nothing(_rng: RandomNumberGenerator) -> int:
	return 0

# If a hint is 0 or the size of row/col, hide it. This makes puzzles more interesting.
static func hide_obvious_hints(grid: GridModel) -> void:
	var hints := grid.row_hints()
	for i in grid.rows():
		if hints[i].water_count == grid.cols() or hints[i].water_count == 0:
			hints[i].water_count_type = E.HintType.Hidden
	hints = grid.col_hints()
	for j in grid.cols():
		if hints[j].water_count == grid.rows() or hints[j].water_count == 0:
			hints[j].water_count_type = E.HintType.Hidden

static func _easy_visibility(_rng: RandomNumberGenerator, grid: GridModel) -> void:
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)

static func _medium_visibility(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.new()
	for _i in grid.rows():
		h.row.append(0)
	for _j in grid.cols():
		h.col.append(0)
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(3, a.size() + 2), a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size() - 2), 0))
	h.apply_to_grid(grid)
	hide_obvious_hints(grid)


static func _hard_visibility(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.new()
	h.total_boats = rng.randf() < 0.5
	h.total_water = rng.randf() < 0.3
	for i in grid.rows():
		h.row.append(0)
	for j in grid.cols():
		h.col.append(0)
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(1, a.size() + 3), a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size()), 0))
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() / 2)))
	h.apply_to_grid(grid)
	hide_obvious_hints(grid)

# We're using this to generate seeds from sequential numbers since Godot docs says
# similar seeds might lead to similar values.
static func consistent_hash(x: String) -> int:
	return x.sha1_buffer().decode_s64(0)

func _on_dif_pressed(dif: Difficulty) -> void:
	if not await _confirm_new_level():
		return
	var rng := RandomNumberGenerator.new()
	var seed_str: String = $Seed.text
	if seed_str.is_empty():
		var data := UserData.current()
		data.random_levels_created[dif] += 1
		var i := data.random_levels_created[dif]
		rng.seed = RandomHub.consistent_hash(str(i))
		UserData.save()
		var success_state := PreprocessedDifficulty.current(dif).success_state(i)
		if success_state != 0:
			rng.state = success_state
	else:
		rng.seed = RandomHub.consistent_hash(seed_str)
	gen_and_play(rng, dif)



func _on_cancel_gen_pressed():
	gen.cancel()


func _on_custom_seed_button_pressed() -> void:
	$CustomSeedButton.visible = false
	$Seed.visible = true
