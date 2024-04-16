extends Control

const DESIRED_W := 780.0

@onready var g1: GridView = $Grid1
@onready var g2: GridView = $Grid2

# Runs tests, in the future, we can make this more extendable, test classes
# and stuffs. But for now, this is enough.

func _ready() -> void:
	$BrushPicker.setup(true, true)
	for section in range(1, ExtraLevelLister.count_all_game_sections(true) + 1):
		if ExtraLevelLister.section_endless_flavor(section) != -1:
			%EndlessOptions.add_item(ExtraLevelLister.section_name(section), section)

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

const PLAYED_STATS := ["daily2", "editor", "playtest", "random"]
const INT_STATS := ["daily_all_levels", "random_all_levels", "random_insane_levels", "random_insane_good_levels"]

func _on_print_global_stats_pressed() -> void:
	if not SteamManager.enabled:
		return
	SteamManager.steam.requestGlobalStats(5)
	await SteamManager.steam.global_stats_received
	for stat in PLAYED_STATS:
		var val = SteamManager.steam.getGlobalStatFloat(stat + "_secs")
		var tot = SteamManager.steam.getGlobalStatInt(stat + "_total")
		print("%s = %s tot %s avg" % [stat, Level.time_str(int(val)), Level.time_str(int(val / tot))])
	for stat in INT_STATS:
		var val = SteamManager.steam.getGlobalStatInt(stat)
		print("%s = %d" % [stat, val])


func _on_print_local_stats_pressed():
	if not SteamManager.enabled:
		return
	for stat in PLAYED_STATS:
		var val = SteamManager.steam.getStatFloat(stat + "_secs")
		var tot = SteamManager.steam.getStatInt(stat + "_total")
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
	var watch := Stopwatch.new()
	while true:
		var date := Time.get_datetime_string_from_unix_time(unixtime)
		date = date.substr(0, date.find("T"))
		if not date.begins_with(str(year)) or %DailiesCancel.button_pressed:
			break
		var dict := Time.get_datetime_dict_from_datetime_string(date, false)
		if prep.success_state(dict) == 0:
			await DailyButton.gen_level(gen, date)
			prep.set_success_state(dict, gen.success_state)
		elif $Buttons/PrepCheck.button_pressed:
			# Check it is correct
			await DailyButton.gen_level(gen, date)
		if watch.elapsed() > 60.:
			watch.elapsed_reset()
			FileManager.save_dailies(year, prep)
		%DailiesProgress.value += 1
		unixtime += 24 * 60 * 60
	%DailiesProgress.visible = false
	%DailiesYear.visible = true
	%DailiesButton.visible = true
	%DailiesCancel.visible = false
	FileManager.save_dailies(year, prep)


func _on_dif_button_pressed():
	var dif: RandomHub.Difficulty = %DifOptions.get_selected_id()
	var prep := FileManager.load_preprocessed_difficulty(dif)
	var gen := RandomLevelGenerator.new()
	%DifProgress.value = 0
	%DifProgress.visible = true
	%DifOptions.disabled = true
	%DifButton.visible = false
	%DifCancel.visible = true
	%DifCancel.button_pressed = false
	var watch := Stopwatch.new()
	var rng := RandomNumberGenerator.new()
	for i in 1000:
		if %DifCancel.button_pressed:
			break
		rng.seed = RandomHub.consistent_hash(str(i))
		if prep.success_state(i) == 0:
			await RandomHub.gen_from_difficulty(gen, rng, dif)
			prep.set_success_state(i, gen.success_state)
		elif $Buttons/PrepCheck.button_pressed:
			# Check it is correct
			rng.state = prep.success_state(i)
			await RandomHub.gen_from_difficulty(gen, rng, dif)
			assert(gen.success_state == prep.success_state(i))
		if watch.elapsed() > 60.:
			watch.elapsed_reset()
			FileManager.save_preprocessed_difficulty(prep)
		%DifProgress.value += 1
	%DifCancel.visible = false
	%DifProgress.visible = false
	%DifButton.visible = true
	%DifOptions.disabled = false
	FileManager.save_preprocessed_difficulty(prep)

func _on_endless_button_pressed() -> void:
	var section: int = %EndlessOptions.get_selected_id()
	var prep := FileManager.load_preprocessed_endless(section)
	var gen := RandomLevelGenerator.new()
	var flavor := ExtraLevelLister.section_endless_flavor(section) as RandomFlavors.Flavor
	%EndlessProgress.value = 0
	%EndlessProgress.visible = true
	%EndlessOptions.disabled = true
	%EndlessButton.visible = false
	%EndlessCancel.visible = true
	%EndlessCancel.button_pressed = false
	var watch := Stopwatch.new()
	var rng := RandomNumberGenerator.new()
	for i in 1000:
		if %EndlessCancel.button_pressed:
			break
		rng.seed = RandomHub.consistent_hash(str(i))
		if prep.success_state(i) == 0:
			await RandomFlavors.gen(gen, rng, flavor)
			prep.set_success_state(i, gen.success_state)
		elif $Buttons/PrepCheck.button_pressed:
			# Check it is correct
			rng.state = prep.success_state(i)
			await RandomFlavors.gen(gen, rng, flavor)
			assert(gen.success_state == prep.success_state(i))
		if watch.elapsed() > 30.:
			watch.elapsed_reset()
			FileManager.save_preprocessed_endless(section, prep)
		%EndlessProgress.value += 1
	%EndlessCancel.visible = false
	%EndlessProgress.visible = false
	%EndlessButton.visible = true
	%EndlessOptions.disabled = false
	FileManager.save_preprocessed_endless(section, prep)

func _on_reset_stats_pressed():
	SteamManager.steam.resetAllStats(true)
	SteamManager.steam.requestCurrentStats()


func _on_preprocess_weeklies_pressed() -> void:
	var year := int(%WeekliesYear.value)
	var prep := FileManager.load_preprocessed_weeklies(year)
	var first_monday: String = PreprocessedWeeklies.first_monday_of_the_year(year)
	if year == 2024:
		# We didn't have weeklies before this.
		first_monday = "2024-03-11"
	var unixtime := Time.get_unix_time_from_datetime_string(first_monday)
	var gen := RandomLevelGenerator.new()
	%WeekliesProgress.value = 0
	%WeekliesProgress.visible = true
	%WeekliesButton.visible = false
	%WeekliesYear.visible = false
	%WeekliesCancel.visible = true
	%WeekliesCancel.button_pressed = false
	var watch := Stopwatch.new()
	while true:
		var monday := Time.get_datetime_string_from_unix_time(unixtime)
		monday = monday.substr(0, monday.find("T"))
		for i in 10:
			if not monday.begins_with(str(year)) or %WeekliesCancel.button_pressed:
				break
			if prep.success_state(monday, i) == 0:
				await WeeklyButton.gen_level(gen, monday, i + 1, 10)
				prep.set_success_state(monday, i, gen.success_state)
			elif $Buttons/PrepCheck.button_pressed:
				# Check it is correct
				await WeeklyButton.gen_level(gen, monday, i + 1, 10)
			if watch.elapsed() > 30.:
				watch.elapsed_reset()
				FileManager.save_preprocessed_weeklies(2024, prep)
		%WeekliesProgress.value += 1
		unixtime += 7 * 24 * 60 * 60
	%WeekliesProgress.visible = false
	%WeekliesYear.visible = true
	%WeekliesButton.visible = true
	%WeekliesCancel.visible = false
	FileManager.save_preprocessed_weeklies(2024, prep)
