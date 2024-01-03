# Very hard levels generated with certain interesting pattern of hints
class_name RandomFlavors

# Monday - Simple, basic hints, larger
# Tuesday - Diagonals, together/separate
# Wednesday - Simple, hidden hints
# Thursday - Diagonals, basic hints
# Friday - Simple, boats
# Saturday - Simple, together/separate
# Sunday - Diagonals, boats
# Basic Monday
# Secret Boat Tuesday
# Hidden Thursday
# Freaky Friday
enum Flavor {
	Sunday = Time.WEEKDAY_SUNDAY,
	Monday,
	Tuesday,
	Wednesday,
	Thursday,
	Friday,
	Saturday,
	# All water hints are {?}, -?- or 0. There are boats and total water hints.
	BoatsHiddenWater,
	# All row boat hints are {?}, -?- or 0. All water hints are ? or N.
	SecretBoats,
	# Always has diagonals, boats, aquariums and {-.
	Everything,
	# All aquarium rules visible, nothing else
	Aquariums,
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
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_TYPE_VISIBLE, rng.randi_range(-2, a.size()))
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
	# Just the sum of aquarium sizes, no need to hide and expect people to do math.
	h.total_water = true
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-3, a.size() - 1))
		#RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-3, a.size() - 1))
	h.expected_aquariums.assign(grid.all_aquarium_counts().keys())
	h.apply_to_grid(grid)

static func _fixed_opts(opts: int) -> Callable:
	return func(_rng: RandomNumberGenerator) -> int:
		return opts

static func gen(l_gen: RandomLevelGenerator, rng: RandomNumberGenerator, flavor: Flavor) -> GridModel:
	var strategies := SolverModel.STRATEGY_LIST.keys()
	match flavor:
		Flavor.Monday:
			return await l_gen.generate(rng,7, 7, RandomFlavors._simple_hints, _fixed_opts(0), strategies, [])
		Flavor.Tuesday:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._continuity_hints, _fixed_opts(1), strategies, [])
		Flavor.Wednesday:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._hidden_hints, _fixed_opts(0), strategies, [])
		Flavor.Thursday:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._simple_hints, _fixed_opts(1), strategies, [])
		Flavor.Friday:
			var g := await l_gen.generate(rng, 7, 7, RandomFlavors._simple_boats, _fixed_opts(2), strategies, [], true)
			assert(g._any_sol_boats())
			return g
		Flavor.Saturday:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._continuity_hints, _fixed_opts(0), strategies, [])
		Flavor.Sunday:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._continuity_hints, _fixed_opts(3), strategies, [], true)
		Flavor.BoatsHiddenWater:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._boats_hidden_water, _fixed_opts(RandomLevelGenerator.BOATS_FLAG), strategies, [], true)
		Flavor.SecretBoats:
			return await l_gen.generate(rng, 6, 6, RandomFlavors._secret_boats, _fixed_opts(RandomLevelGenerator.BOATS_FLAG), strategies, [], true)
		Flavor.Everything:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._everything, _fixed_opts(3), strategies, [], true)
		Flavor.Aquariums:
			return await l_gen.generate(rng, 4, 4, RandomFlavors._aquariums, _fixed_opts(1), strategies, [])
		_:
			push_error("Unknown flavor %d" % flavor)
			return null
