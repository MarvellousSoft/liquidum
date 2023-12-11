class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Difficulties/VBox/Continue
@onready var Completed: VBoxContainer = $CompletedCount
@onready var GeneratingLevel: Control = $GeneratingLevel
@onready var CancelButton: Button = $GeneratingLevel/PanelContainer/VBoxContainer/Cancel

var completed_count: Array[int]
var gen_thread := Thread.new()
var cancel_gen := false

enum Difficulty { Easy = 0, Medium, Hard, Expert, Insane }

func _ready() -> void:
	$Seed.visible = Global.is_dev_mode()
	$Difficulties/VBox/Easy.tooltip_text = "EASY_TOOLTIP"
	# Unlock difficulty after unlocking this section
	var difs := {
		medium = 1,
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
	call_deferred(&"_update")

func _update() -> void:
	Continue.visible = FileManager.load_level(RANDOM) != null
	completed_count = FileManager.load_user_data().random_levels_completed
	for dif in Difficulty:
		var label: Label = Completed.get_node(dif)
		label.visible = not $Difficulties/VBox.get_node(dif).disabled
		label.text = "%s - %d" % [tr("%s_BUTTON" % dif.to_upper()), completed_count[Difficulty[dif]]]

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.pop_scene()

func _inner_gen_level(rng: RandomNumberGenerator, hints_builder: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array) -> GridModel:
	var g: GridModel = null
	var solver := SolverModel.new()
	var found := false
	var start_time := Time.get_unix_time_from_system()
	for i in 1000:
		if cancel_gen:
			break
		var hints: Level.HintVisibility = hints_builder.call(rng)
		var gen_options: bool = gen_options_builder.call(rng)
		g = Generator.new(rng.randi(), gen_options).generate(hints.row.size(), hints.col.size())
		g.set_auto_update_hints(false)
		for j in 3:
			if cancel_gen:
				break
			hints.apply_to_grid(g)
			var g2 := GridImpl.import_data(g.export_data(), GridModel.LoadMode.Testing)
			g2.clear_content()
			if solver.can_solve_with_strategies(g2, strategies, forced_strategies):
				print("Created level after %d tries and %.1fs" % [i * 3 + j + 1, Time.get_unix_time_from_system() - start_time])
				found = true
				break
			# Let's retry with the same grid but different visibility
			if j < 2:
				hints = hints_builder.call(rng)
		if found:
			break
	return g if not cancel_gen else null

func gen_level(rng: RandomNumberGenerator, dif: Difficulty, hints_builder: Callable, gen_options_builder: Callable, strategies: Array, forced_strategies: Array) -> void:
	if gen_thread.is_alive():
		return
	GeneratingLevel.visible = true
	CancelButton.disabled = false
	cancel_gen = false
	gen_thread.start(func(): return _inner_gen_level(rng, hints_builder, gen_options_builder, strategies, forced_strategies))
	var g: GridModel = await Global.wait_for_thread(gen_thread)
	GeneratingLevel.visible = false
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
	FileManager.save_user_data(UserData.new(completed_count))

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	load_existing()

func _vis_array_or(rng: RandomNumberGenerator, a: Array[int], val: int, count: int) -> void:
	var b: Array[int] = []
	for i in a.size():
		b.append(val if i < count else 0)
	Global.shuffle(b, rng)
	for i in a.size():
		a[i] |= b[i]

func _true(_rng: RandomNumberGenerator) -> bool:
	return true

func _false(_rng: RandomNumberGenerator) -> bool:
	return false

func _easy_visibility(_rng: RandomNumberGenerator) -> Level.HintVisibility:
	return Level.HintVisibility.default(5, 5)

func _medium_visibility(rng: RandomNumberGenerator) -> Level.HintVisibility:
	var h := Level.HintVisibility.new()
	for i in 6:
		h.row.append(0)
		h.col.append(0)
	for a in [h.row, h.col]:
		_vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(3, 8), 6))
		_vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, 4), 0))
	return h


func _hard_visibility(n: int, m: int) -> Callable:
	return func(rng: RandomNumberGenerator) -> Level.HintVisibility:
		var h := Level.HintVisibility.new()
		for i in n:
			h.row.append(0)
		for j in m:
			h.col.append(0)
		for a in [h.row, h.col]:
			_vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, mini(rng.randi_range(1, a.size() + 3), a.size()))
			_vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, maxi(rng.randi_range(-3, a.size()), 0))
		return h

func _on_dif_pressed(dif: Difficulty) -> void:
	if not await _confirm_new_level():
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = randi() if $Seed.text.is_empty() else int($Seed.text)
	match dif:
		Difficulty.Easy:
			gen_level(rng, dif, _easy_visibility, _false, ["BasicRow", "BasicCol"], [])
		Difficulty.Medium:
			gen_level(rng, dif, _medium_visibility, _false, ["BasicCol", "BasicRow", "TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol"], ["MediumCol", "MediumRow"])
		Difficulty.Hard:
			gen_level(rng, dif, _hard_visibility(4, 5), _true, ["BasicCol", "BasicRow", "MediumCol", "MediumRow"], ["TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol", "BoatRow", "BoatCol"])
		Difficulty.Expert:
			gen_level(rng, dif, _hard_visibility(5, 5), _true, ["BasicCol", "BasicRow", "MediumCol", "MediumRow"], ["TogetherRow", "TogetherCol", "SeparateRow", "SeparateCol", "BoatRow", "BoatCol", "AdvancedRow"])
		Difficulty.Insane:
			pass
		_:
			push_error("Uknown difficulty %d" % dif)


func _on_cancel_gen_pressed():
	cancel_gen = true
	CancelButton.disabled = true
