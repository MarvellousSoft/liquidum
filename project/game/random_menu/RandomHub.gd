class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Difficulties/VBox/Continue
@onready var ContinueSeparator: HSeparator = $Difficulties/VBox/ContinueSeparator
@onready var Completed: VBoxContainer = $CompletedCount

var completed_count: Array[int]
var gen := RandomLevelGenerator.new()

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
	
func _enter_tree() -> void:
	GeneratingLevel.cancel.connect(_on_cancel_gen_pressed)
	call_deferred(&"_update")

func _exit_tree() -> void:
	GeneratingLevel.cancel.disconnect(_on_cancel_gen_pressed)

func _update() -> void:
	var has_random_level := FileManager.load_level(RANDOM) != null
	Continue.visible = has_random_level
	ContinueSeparator.visible = has_random_level
	completed_count = UserData.current().random_levels_completed
	for dif in Difficulty:
		var label: Label = Completed.get_node(dif)
		label.visible = not $Difficulties/VBox.get_node(dif).disabled
		label.text = "%s - %d" % [tr("%s_BUTTON" % dif.to_upper()), completed_count[Difficulty[dif]]]

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.pop_scene()

func gen_level(rng: RandomNumberGenerator, dif: Difficulty, hints_builder: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array) -> void:
	if gen.running():
		return
	GeneratingLevel.enable()
	var g := await gen.generate(rng, hints_builder, gen_options_builder, strategies, forced_strategies)
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
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), RANDOM, data.full_name, "")
	level.won.connect(_level_completed.bind(data.difficulty))
	TransitionManager.push_scene(level)

func _confirm_new_level() -> bool:
	AudioManager.play_sfx("button_pressed")
	if Continue.visible and ConfirmationScreen.start_confirmation(&"CONFIRM_NEW_RANDOM"):
		return await ConfirmationScreen.pressed
	return true

func _level_completed(dif: Difficulty) -> void:
	# Save was already deleted
	completed_count[dif] += 1
	UserData.current().random_levels_completed = completed_count
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

func _expert_options(rng: RandomNumberGenerator) -> int:
	return (1 if rng.randf() < 0.5 else 0) + (2 if rng.randf() < 0.35 else 0)

func _diags(rng: RandomNumberGenerator) -> int:
	return 1 + (2 if rng.randf() < 0.5 else 0) 

func _nothing(_rng: RandomNumberGenerator) -> int:
	return 0

func _easy_visibility(_rng: RandomNumberGenerator) -> Level.HintVisibility:
	return Level.HintVisibility.default(5, 5)

static func _medium_visibility(rng: RandomNumberGenerator) -> Level.HintVisibility:
	var h := Level.HintVisibility.new()
	for i in 6:
		h.row.append(0)
		h.col.append(0)
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(3, 8), 6))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, 4), 0))
	return h


static func _hard_visibility(n: int, m: int) -> Callable:
	return func(rng: RandomNumberGenerator) -> Level.HintVisibility:
		var h := Level.HintVisibility.new()
		h.total_boats = rng.randf() < 0.5
		h.total_water = rng.randf() < 0.3
		for i in n:
			h.row.append(0)
		for j in m:
			h.col.append(0)
		for a in [h.row, h.col]:
			RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(1, a.size() + 3), a.size()))
			RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size()), 0))
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() / 2)))
		return h

func _on_dif_pressed(dif: Difficulty) -> void:
	if not await _confirm_new_level():
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = randi() if $Seed.text.is_empty() else int($Seed.text)
	match dif:
		Difficulty.Easy:
			gen_level(rng, dif, _easy_visibility, _nothing, ["BasicRow", "BasicCol"], [])
		Difficulty.Medium:
			gen_level(rng, dif, _medium_visibility, _nothing, ["BasicCol", "BasicRow", "TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol"], ["MediumCol", "MediumRow"])
		Difficulty.Hard:
			gen_level(rng, dif, RandomHub._hard_visibility(5, 4), _diags, ["BasicCol", "BasicRow", "MediumCol", "MediumRow", "AllWatersEasy", "BoatRow"], ["TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol", "BoatCol", "AllBoats", "AllWatersMedium"])
		Difficulty.Expert:
			gen_level(rng, dif, RandomHub._hard_visibility(5, 5), _expert_options, ["BasicCol", "BasicRow", "MediumCol", "MediumRow", "BoatRow", "BoatCol", "AllWatersEasy", "AllWatersMedium", "AllBoats"], ["TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol", "AdvancedRow", "AdvancedCol"])
		Difficulty.Insane:
			gen_level(rng, dif, RandomHub._hard_visibility(6, 6), _expert_options, SolverModel.STRATEGY_LIST.keys(), [])
		_:
			push_error("Uknown difficulty %d" % dif)


func _on_cancel_gen_pressed():
	gen.cancel()
