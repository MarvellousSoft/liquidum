# Very hard levels generated with certain interesting pattern of hints
class_name RandomFlavors

# Monday - Simple, basic hints, larger
# Tuesday - Diagonals, together/separate
# Wednesday - Simple, hidden hints
# Thursday - Diagonals, basic hints
# Friday - Simple, boats
# Saturday - Simple, together/separate
# Sunday - Diagonals, boats
enum Flavor {
	Sunday = Time.WEEKDAY_SUNDAY,
	Monday,
	Tuesday,
	Wednesday,
	Thursday,
	Friday,
	Saturday,
}

static func _simple_hints(_rng: RandomNumberGenerator, grid: GridModel) -> void:
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)
	# RandomHub.hide_obvious_hints(grid) Don't hide otherwise it's obvious it's 0

static func _simple_boats(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.default(grid.rows(), grid.cols())
	h.total_boats = rng.randf() < 0.5
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, ceili(a.size() * .75)))
	h.apply_to_grid(grid)
	# RandomHub.hide_obvious_hints(grid) Don't hide otherwise it's obvious it's 0

static func _continuity_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	RandomHub._hard_visibility(rng, grid)

static func _hidden_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.new()
	h.total_water = rng.randf() < 0.5
	for i in grid.rows():
		h.row.append(0)
	for j in grid.cols():
		h.col.append(0)
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size() - 1))
	h.apply_to_grid(grid)
	RandomHub.hide_obvious_hints(grid)

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
		_:
			push_error("Unknown flavor %d" % flavor)
			return null
