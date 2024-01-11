extends Control

const DESIRED_W := 780.0

@onready var g1: GridView = $Grid1
@onready var g2: GridView = $Grid2

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _ready() -> void:
	$BrushPicker.setup(true)

func _on_run_pressed():
	$Tests.run_all_tests()

func _on_tests_show_grids(s1: String, s2: String):
	g1.setup(GridImpl.from_str(s1, GridModel.LoadMode.Testing))
	g2.setup(GridImpl.from_str(s2, GridModel.LoadMode.Testing))
	scale_grids()


func scale_grids() -> void:
	await get_tree().process_frame
	var s := DESIRED_W / g2.get_grid_size().x
	g1.scale = Vector2(s, s)
	g2.scale = Vector2(s, s)

func all_strategies() -> Array:
	return SolverModel.STRATEGY_LIST.keys()


func _on_auto_solve_pressed():
	g2.apply_strategies(all_strategies())


func _on_grid_2_updated():
	if $Buttons/GodMode.button_pressed:
		g2.apply_strategies(all_strategies(), false, false)


func _on_paste_pressed():
	g2.setup(GridImpl.from_str(DisplayServer.clipboard_get(), GridModel.LoadMode.Solution))
	scale_grids()


func _on_full_solve_pressed():
	var r := g2.full_solve(all_strategies())
	var solve_type: String = SolverModel.SolveResult.find_key(r)
	print("Level is %s" % solve_type)
	$Buttons/SolvedType.text = solve_type

const PLAYED_STATS := ["daily", "editor", "playtest", "random"]
const INT_STATS := ["daily_levels", "random_all_levels", "random_insane_levels"]

func _on_print_global_stats_pressed() -> void:
	if not SteamManager.enabled:
		return
	SteamManager.steam.requestGlobalStats(5)
	await SteamManager.steam.global_stats_received
	for stat in PLAYED_STATS:
		var val := SteamManager.steam.getGlobalStatFloat(stat + "_secs")
		var tot := SteamManager.steam.getGlobalStatInt(stat + "_total")
		print("%s = %.0f tot %.0f avg" % [stat, val, val / tot])


func _on_print_local_stats_pressed():
	if not SteamManager.enabled:
		return
	for stat in PLAYED_STATS:
		var val := SteamManager.steam.getStatFloat(stat + "_secs")
		var tot := SteamManager.steam.getStatInt(stat + "_total")
		print("%s = %.0f (total %d)" % [stat, val, tot])
	for int_stat in INT_STATS:
		print("%s = %d" % [int_stat, SteamManager.steam.getStatInt(int_stat)])


func _on_preprocess_dailies_pressed() -> void:
	var year: int = int(%DailiesYear.value)
	var prep := FileManager.load_dailies(year)
	var unixtime := Time.get_unix_time_from_datetime_string("%s-01-01" % year)
	var gen := RandomLevelGenerator.new()
	%DailiesProgress.value = 0
	%DailiesProgress.visible = true
	%DailiesYear.visible = false
	%DailiesButton.visible = false
	%DailiesCancel.visible = true
	%DailiesCancel.button_pressed = false
	while true:
		var date := Time.get_datetime_string_from_unix_time(unixtime)
		date = date.substr(0, date.find("T"))
		if not date.begins_with(str(year)) or %DailiesCancel.button_pressed:
			break
		var dict := Time.get_datetime_dict_from_datetime_string(date, false)
		if prep.success_state(dict) == 0:
			await DailyButton.gen_level(gen, date)
			prep.set_success_state(dict, gen.success_state)
		%DailiesProgress.value += 1
		unixtime += 24 * 60 * 60
	%DailiesProgress.visible = false
	%DailiesYear.visible = true
	%DailiesButton.visible = true
	%DailiesCancel.visible = false
	FileManager.save_dailies(year, prep)


func _on_dif_button_pressed():
	var dif: RandomHub.Difficulty = %DifOptions.get_selected_id()
	var prep := PreprocessedDifficulty.current(dif)
	var gen := RandomLevelGenerator.new()
	%DifProgress.value = 0
	%DifProgress.visible = true
	%DifOptions.disabled = true
	%DifButton.visible = false
	%DifCancel.visible = true
	%DifCancel.button_pressed = false
	var rng := RandomNumberGenerator.new()
	for i in 1000:
		if %DifCancel.button_pressed:
			break
		if prep.success_state(i) == 0:
			rng.seed = RandomHub.consistent_hash(str(i))
			await RandomHub.gen_from_difficulty(gen, rng, dif)
			prep.set_success_state(i, gen.success_state)
		%DifProgress.value += 1
	%DifCancel.visible = false
	%DifProgress.visible = false
	%DifButton.visible = true
	%DifOptions.disabled = false
	FileManager.save_preprocessed_difficulty(prep)
