# Very hard levels generated with certain interesting pattern of hints
class_name RandomFlavors

# Basic Monday
# Secret Boat Tuesday
# Diagonal Wednesday
# Hidden Thursday
# Freaky Friday
# One Hint Saturday
# Aquarium Sunday
enum Flavor {
	# Many aquarium rules visible.
	Aquariums = Time.WEEKDAY_SUNDAY,
	# No diagonals, boats, aquariums, hidden hints or {-
	Basic,
	# All row boat hints are {?}, -?- or 0. All water hints are ? or N.
	SecretBoats,
	# Diagonals, simple hints
	Diagonals,
	# All water hints are {?}, -?- or 0. There are boats and total water hints.
	BoatsHiddenWater,
	# Always has diagonals, boats, aquariums and {-.
	Everything,
	# A single hint in the row.
	OneHint,
	# small grid, diagonals, basic rules + ?
	TrickySmall,
	# Aquariums and only {?} and -?-
	AquariumTogether,
	# Beautiful levels
	FemmeFatale,
}

static func _simple_hints(_rng: RandomNumberGenerator, grid: GridModel) -> void:
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)
	# RandomHub.hide_too_easy_hints(grid) Don't hide otherwise it's obvious it's 0

static func _simple_boats(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.default(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() * .75)))
	h.apply_to_grid(grid)
	# RandomHub.hide_too_easy_hints(grid) Don't hide otherwise it's obvious it's 0

static func _continuity_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	RandomHub._hard_visibility(rng, grid)

static func _hidden_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = rng.randf() < 0.5
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size() - 1))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

static func _boats_hidden_water(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.default(grid.rows(), grid.cols(), HintBar.WATER_TYPE_VISIBLE)
	h.total_boats = true
	h.total_water = true
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(1, a.size() + 3))
		if a == h.row:
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_TYPE_VISIBLE, rng.randi_range( - 2, a.size()))
	h.apply_to_grid(grid)
	for i in grid.rows():
		if grid.count_water_row(i) == 0:
			grid.row_hints()[i].water_count = 0
	for j in grid.cols():
		if grid.count_water_col(j) == 0:
			grid.col_hints()[j].water_count = 0

static func _secret_boats(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_boats = true
	h.total_water = rng.randf() < 0.5
	for i in grid.rows():
		if grid.count_boat_row(i) == 0:
			h.row[i] |= HintBar.BOAT_COUNT_VISIBLE
		else:
			h.row[i] |= HintBar.BOAT_TYPE_VISIBLE
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size() + 3))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

static func _everything(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_boats = true
	h.total_water = true
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size() - 1))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(1, a.size() - 1))
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(1, a.size() - 1))
		if a == h.row:
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_TYPE_VISIBLE, rng.randi_range(1, a.size() - 1))
	h.apply_to_grid(grid)
	Generator.randomize_aquarium_hints(rng, grid)
	RandomHub.hide_too_easy_hints(grid)

static func _aquariums(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = true
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-3, a.size() - 2))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)
	Generator.randomize_aquarium_hints(rng, grid, 0.66)

static func _one_hint(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = true
	var a: Array[int] = h.col
	var b: Array[int] = h.row
	RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(a.size(), a.size() + 2))
	RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(a.size(), a.size() + 2))
	RandomHub._vis_array_or(rng, b, HintBar.WATER_COUNT_VISIBLE | HintBar.WATER_TYPE_VISIBLE, 1)
	h.apply_to_grid(grid)
	#RandomHub.hide_too_easy_hints(grid, false, true)

static func _tricky_small(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = rng.randf() < 0.25
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-3, a.size()))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

static func _aquarium_together(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = true
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-6, a.size()))
	h.apply_to_grid(grid)
	Generator.randomize_aquarium_hints(rng, grid, 0.7)

static func _builder(options: Generator.Options) -> Callable:
	return func(_rng: RandomNumberGenerator) -> Generator.Options:
		return options

static func _aquarium_builder(rng: RandomNumberGenerator) -> Generator.Options:
	return Generator.builder().with_diags().with_aquariums(rng.randi_range(6, 10)).with_min_water(rng.randi_range(10, 14))

static func _aquarium_together_builder(rng: RandomNumberGenerator) -> Generator.Options:
	return Generator.builder().with_aquariums(rng.randi_range(10, 20)).with_min_water(rng.randi_range(12, 18))

static func _femme_fatale_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	h.total_water = rng.randf() < 0.25
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-2, a.size()))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-6, a.size() + 1))
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(-6, a.size()))
		if a == h.row:
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_TYPE_VISIBLE, rng.randi_range(-10, a.size()))
	h.apply_to_grid(grid)
	if rng.randf() < 0.25:
		Generator.randomize_aquarium_hints(rng, grid)
	RandomHub.hide_too_easy_hints(grid)

static func _femme_fatale_builder(rng: RandomNumberGenerator) -> Generator.Options:
	# We don't want to be affected by the current state, but still depend on the RNG so we can
	# preprocess. Otherwise this wouldn't matter because we would always choose a different mod_i
	var new_rng := RandomNumberGenerator.new()
	new_rng.seed = rng.seed
	var opts := ExistingLevelGenerator.custom_builder("femme_fatale") \
	  .with_mod_max(5) \
	  .with_mod_i(new_rng.randi_range(0, 4))
	if rng.randf() < 0.3:
		opts = opts.with_boats()
	return opts

static func gen(l_gen: RandomLevelGenerator, rng: RandomNumberGenerator, flavor: Flavor) -> GridModel:
	# WARNING: DO NOT use rng before calling l_gen.generate or preprocessing won't work
	var strategies := SolverModel.STRATEGY_LIST.keys()
	var b := Generator.builder()
	match flavor:
		Flavor.Diagonals:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._simple_hints, _builder(b.with_diags()), strategies, [])
		Flavor.Basic:
			return await l_gen.generate(rng, 7, 7, RandomFlavors._simple_hints, _builder(b), strategies, [])
		Flavor.BoatsHiddenWater:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._boats_hidden_water, _builder(b.with_boats()), strategies, [], true)
		Flavor.SecretBoats:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._secret_boats, _builder(b.with_boats()), strategies, [], true)
		Flavor.Everything:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._everything, _builder(b.with_diags().with_boats()), strategies, [], true)
		Flavor.Aquariums:
			return await l_gen.generate(rng, 5, 4, RandomFlavors._aquariums, RandomFlavors._aquarium_builder, strategies, [])
		Flavor.OneHint:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._one_hint, _builder(b), strategies, [])
		Flavor.TrickySmall:
			var size_gen := func(my_rng: RandomNumberGenerator):
				return Vector2i(my_rng.randi_range(3, 4), my_rng.randi_range(3, 4))
			return await l_gen.generate_with_size(rng, size_gen, RandomFlavors._tricky_small, _builder(b.with_diags()), strategies, [])
		Flavor.AquariumTogether:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._aquarium_together, RandomFlavors._aquarium_together_builder, strategies, [], false)
		Flavor.FemmeFatale:
			return await l_gen.generate(rng, -1, -1, RandomFlavors._femme_fatale_hints, RandomFlavors._femme_fatale_builder, strategies, [], false)
		_:
			push_error("Unknown flavor %d" % flavor)
			return null
