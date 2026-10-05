class_name PandoraHub
extends RandomHub

const PANDORA := "pandora"

enum Mode {
	Snake = 0,
	Sudoku = 1,
	Knight = 2,
	Liar = 3,
	Symbols = 4,
	Pandora = 5,
}

const PANDORA_FLAVORS: Array[RandomFlavors.Flavor] = [
	RandomFlavors.Flavor.Snake,
	RandomFlavors.Flavor.Sudoku,
	RandomFlavors.Flavor.Knight,
	RandomFlavors.Flavor.Liar,
	RandomFlavors.Flavor.Symbols,
]

var _current_flavor: int = -1

func _save_level_name() -> String:
	return PANDORA

func _load_level_data() -> LevelData:
	return FileManager.load_pandora_level()

func _save_level_data(data: LevelData) -> void:
	FileManager.save_pandora_level(data)

func _get_modes() -> Array[int]:
	var modes: Array[int] = []
	modes.assign(Mode.values())
	return modes

func _mode_name(mode: int) -> String:
	return Mode.find_key(mode)

func _mode_button_key(mode: int) -> String:
	return "%s_BUTTON" % _mode_name(mode).to_upper()

func _mode_button_text(mode: int) -> String:
	return tr(_mode_button_key(mode))

func _get_completed_node(mode: int) -> Node:
	if Completed == null or mode == Mode.Pandora:
		return null
	return Completed.get_node_or_null(_mode_name(mode))

func _get_completed_count(mode: int) -> int:
	return UserData.current().get_pandora_completed(mode)

func _bump_created_count(mode: int) -> int:
	var count := UserData.current().bump_pandora_created(mode)
	UserData.save()
	return count

func _get_preprocessed_state(mode: int, seed_int: int) -> int:
	return PreprocessedPandora.current(mode).success_state(seed_int)

func _confirm_new_text() -> StringName:
	return &"CONFIRM_NEW_RANDOM"

func _get_tracking(data: LevelData) -> Array[String]:
	var tracking: Array[String] = ["pandora", "pandora_%s" % _mode_name(data.difficulty).to_lower()]
	if data.marathon_left != -1:
		tracking.append("marathon")
	return tracking

func _mode_to_flavor(mode: int) -> RandomFlavors.Flavor:
	match mode:
		Mode.Snake:
			return RandomFlavors.Flavor.Snake
		Mode.Sudoku:
			return RandomFlavors.Flavor.Sudoku
		Mode.Knight:
			return RandomFlavors.Flavor.Knight
		Mode.Liar:
			return RandomFlavors.Flavor.Liar
		Mode.Symbols:
			return RandomFlavors.Flavor.Symbols
		_:
			return RandomFlavors.Flavor.Snake

func _generate_grid(rng: RandomNumberGenerator, mode: int, marathon_left: int, marathon_total: int, seed_str: String, l_gen: RandomLevelGenerator = gen) -> GridModel:
	var flavor: RandomFlavors.Flavor
	if mode == Mode.Pandora:
		if marathon_total > 1:
			var shuffled_flavors: Array[RandomFlavors.Flavor] = PANDORA_FLAVORS.duplicate()
			var shuffle_rng := RandomNumberGenerator.new()
			shuffle_rng.seed = RandomHub.consistent_hash(seed_str)
			Global.shuffle(shuffled_flavors, shuffle_rng)
			var current_idx: int = marathon_total - (marathon_left + 1)
			flavor = shuffled_flavors[current_idx % shuffled_flavors.size()]
		else:
			var flavor_rng := RandomNumberGenerator.new()
			flavor_rng.seed = RandomHub.consistent_hash(seed_str + "-flavor")
			flavor = PANDORA_FLAVORS[flavor_rng.randi() % PANDORA_FLAVORS.size()]
	else:
		flavor = _mode_to_flavor(mode)
	
	_current_flavor = flavor
	return await RandomFlavors.gen(l_gen, rng, flavor)

func _setup_level_data(data: LevelData, mode: int, _marathon_left: int, _marathon_total: int, _seed_str: String) -> void:
	data.flavor = _current_flavor
	data.difficulty_name = _mode_button_key(mode)

func _on_level_won(info: Level.WinInfo, level: Level, data: LevelData) -> void:
	var flavor_solved: int = data.flavor
	if flavor_solved == -1 and data.difficulty != Mode.Pandora:
		flavor_solved = data.difficulty
	var u_data := UserData.current()
	if flavor_solved != -1:
		u_data.bump_pandora_completed(flavor_solved)
	var p_section := ExtraLevelLister.pandora_section()
	if p_section != -1:
		u_data.bump_endless_completed(p_section)
		if info.mistakes < 3:
			u_data.bump_endless_good(p_section)
	UserData.save()
	var stats := StatsTracker.instance()
	stats.increment_random_any()
	if data.marathon_left == 0 and shows_marathon_leaderboards(data.marathon_total, data.manually_seeded):
		await RecurringMarathon.upload_leaderboard(marathon_leaderboard(data.marathon_total, data.difficulty), info, true)
		if SteamManager.enabled:
			var l_id := marathon_leaderboard(data.marathon_total, data.difficulty)
			await StoreIntegrations.leaderboard_create_if_not_exists(l_id, StoreIntegrations.SortMethod.SmallestFirst)
			var l_data := await RecurringMarathon.get_leaderboard_data(l_id)
			if not l_data.is_empty():
				var display := LeaderboardDisplay.get_or_create(level, "MARATHON", false, _speedrun_key(data.marathon_total, data.difficulty))
				var mode_name := _mode_button_text(data.difficulty).to_lower()
				display.display(l_data, "%d %s" % [data.marathon_total, mode_name], [], "")

func _speedrun_key(marathon_total: int, mode: int) -> String:
	if marathon_total == 10 and mode == Mode.Pandora:
		return "n2ylrv1d-p85ykw3l.qj7mgjgq"
	elif marathon_total == 100 and mode == Mode.Pandora:
		return "5dw3qq52-p85ykw3l.qj7mgjgq"
	return ""

func _update_unlocked() -> void:
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	for mode in _get_modes():
		var but: Button = _get_mode_button(mode)
		if but != null:
			but.disabled = false
			but.tooltip_text = "%s_TOOLTIP" % _mode_name(mode).to_upper()
	_update_contents()
