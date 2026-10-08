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
	# Cellhints without {-, basic grid.
	CellHints1,
	# Cellhints with {-, diags and allwaters possible.
	CellHints2,
	# Cellhints, and everything else.
	CellHints3,
	# Liar variant, simple rules
	Liar,
	# Sudoku, simple rules
	Sudoku,
	# Knight variant with {-
	Knight,
	# Snake variant with {-
	Snake,
	# Symbols variant, simple rules
	Symbols,
	# Mirros variant, with boats and diags maybe
	Mirrors,
}

static func _mirrors_size_gen(rng: RandomNumberGenerator) -> Vector2i:
	# No odds because it has some hard cases for the boats solver :P
	return Vector2i(rng.randi_range(3, 5), 4 + 2 * rng.randi_range(0, 2))

static func _mirrors_builder(rng: RandomNumberGenerator) -> Generator.Options:
	var opts := Generator.builder().with_mirrors()
	if rng.randf() < 0.35:
		opts.with_boats()
	if rng.randf() < 0.35:
		opts.with_diags()
	return opts

static func _mirrors_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	if not grid.rule_variants().has(GridModel.RuleVariant.Mirrors):
		grid.rule_variants().append(GridModel.RuleVariant.Mirrors)
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = rng.randf() < 0.35
	var any_boats := grid.count_boats() > 0
	h.total_boats = any_boats and rng.randf() < 0.35
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(a.size()*0.05, a.size() * 0.55))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-2, a.size()*.3))
		if any_boats:
			RandomHub._vis_array_or(rng, a, HintBar.BOAT_COUNT_VISIBLE, rng.randi_range(0, a.size()*.5))
	# Remove col hints when they are on both sides, since it doesn't give any info
	for j in (grid.cols()/2):
		var oj := grid.cols() - 1 - j
		var a := h.col[j] | h.col[oj]
		h.col[j] = 0
		h.col[oj] = 0
		for f in [HintBar.WATER_COUNT_VISIBLE, HintBar.WATER_TYPE_VISIBLE, HintBar.BOAT_COUNT_VISIBLE]:
			if (a & f) != 0:
				var nj := j if rng.randf() < 0.5 else grid.cols()-1-j
				h.col[nj] |= f
	h.apply_to_grid(grid)
	#RandomHub.hide_too_easy_hints(grid)
	

static func _symbols_builder(rng: RandomNumberGenerator) -> Generator.Options:
	var opts := Generator.builder().with_min_water(12)
	if rng.randf() < 0.6:
		opts.with_cell_hints(rng.randf_range(0.01, 0.3))
	if rng.randf() < 0.35:
		opts.with_diags()
	return opts

static func _symbols_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	if not grid.rule_variants().has(GridModel.RuleVariant.Symbols):
		grid.rule_variants().append(GridModel.RuleVariant.Symbols)
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.apply_to_grid(grid)
	# for each number, how many times it appears
	var count : Dictionary = {}
	var will_use : Dictionary = {}
	var total_hints := grid.rows() + grid.cols()
	for i in grid.rows():
		var w := grid.count_water_row(i)
		count[w] = count.get(w, 0) + 1
		for j in grid.cols():
			var ch := grid.get_cell(i, j).hints()
			if ch != null:
				w = grid.count_water_adj(i, j)
				count[w] = count.get(w, 0) + 1
				total_hints += 1
	for j in grid.cols():
		var w := grid.count_water_col(j)
		count[w] = count.get(w, 0) + 1
	var hints := count.keys()
	hints.sort_custom(func(a, b): return count[a] > count[b])
	var min_hints_to_remove := rng.randi_range(floori(total_hints * 0.25), floori(total_hints * 0.75))
	while hints.size() > 3 and (min_hints_to_remove > 0 or (hints.size() > 1 and count[hints[hints.size()-2]] == 1)):
		min_hints_to_remove -= count[hints.back()]
		hints.pop_back()
	for hi in hints:
		var has_hints: int = count[hi]
		if has_hints > 2:
			has_hints = mini(has_hints, rng.randi_range(2, has_hints + 2))
		will_use[hi] = has_hints
	Global.shuffle(hints, rng)
	var hint_symbol : Dictionary = {}
	for i in hints.size():
		# Not all occurrences might have symbols
		var symbols : Array[String] = []
		symbols.resize(will_use[hints[i]])
		symbols.fill(String.chr(65 + i))
		if will_use[hints[i]] < count[hints[i]]:
			for _i in (count[hints[i]] - will_use[hints[i]]):
				symbols.append("")
			Global.shuffle(symbols, rng)
		hint_symbol[hints[i]] = symbols
	var get_symbol := func(ct: float):
		var symbols = hint_symbol.get(ct)
		var s := ""
		if symbols != null:
			s = symbols.back()
			symbols.pop_back()
		return s
	for i in grid.rows():
		grid.row_hints()[i].water_alt_text = get_symbol.call(grid.count_water_row(i))
		for j in grid.cols():
			var ch := grid.get_cell(i, j).hints()
			if ch != null:
				ch.water_alt_text = get_symbol.call(grid.count_water_adj(i, j))
				if ch.water_alt_text == "":
					# Kinda cheating to remove it here, but fine
					grid.get_cell(i,j).rem_cell_hints(false)
	for j in grid.cols():
		grid.col_hints()[j].water_alt_text = get_symbol.call(grid.count_water_col(j))

static func _symbols_size_gen(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(4, 7), rng.randi_range(4, 7))

static func _snake_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	if not grid.rule_variants().has(GridModel.RuleVariant.Snake):
		grid.rule_variants().append(GridModel.RuleVariant.Snake)
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	#h.total_water = rng.randf() < 0.4
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, a.size()/2))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(1, a.size()*.75))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

static func _knight_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	if not grid.rule_variants().has(GridModel.RuleVariant.Knight):
		grid.rule_variants().append(GridModel.RuleVariant.Knight)
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = rng.randf() < 0.4
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(0, a.size()/2))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(0, a.size()/2))
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

static func _knight_size_gen(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(6, 9), rng.randi_range(6, 9))

static func _liar_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	if not grid.rule_variants().has(GridModel.RuleVariant.Liar):
		grid.rule_variants().append(GridModel.RuleVariant.Liar)
	Level.HintVisibility.default(grid.rows(), grid.cols()).apply_to_grid(grid)
	var up_pct = rng.randf_range(0.25, 0.75)
	for i in grid.rows():
		var w := grid.count_water_row(i)
		var d := 1 if w <= grid.cols() - 2 and (w < 2 or rng.randf() < up_pct) else -1
		grid.row_hints()[i].water_alt_text = str(w + d)
	for j in grid.cols():
		var w := grid.count_water_col(j)
		var d := 1 if w <= grid.rows() - 2 and (w < 2 or rng.randf() < up_pct) else -1
		grid.col_hints()[j].water_alt_text = str(grid.count_water_col(j) + d)

static func _liar_size_gen(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(5, 8), rng.randi_range(5, 8))

static func _sudoku_hints(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-4, 5))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-1, 5))
	var cellhints: Array[int] = []
	for i in grid.rows():
		for j in grid.cols():
			if grid.get_cell(i, j).hints() != null:
				cellhints.append(0)
	RandomHub._vis_array_or(rng, cellhints, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(-4, 3))
	RandomHub._vis_array_or(rng, cellhints, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-2, 4))
	for i in grid.rows():
		for j in grid.cols():
			if grid.get_cell(i, j).hints() != null:
				var v: int = cellhints.pop_back()
				h.cells[Vector2i(i, j)] = v
	RandomHub.hide_too_easy_hints(grid)
	h.apply_to_grid(grid)
	if not grid.rule_variants().has(GridModel.RuleVariant.Sudoku):
		grid.rule_variants().append(GridModel.RuleVariant.Sudoku)

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
	const VIS := [HintBar.WATER_COUNT_VISIBLE, HintBar.WATER_TYPE_VISIBLE, HintBar.WATER_COUNT_VISIBLE | HintBar.WATER_TYPE_VISIBLE]
	for i in grid.rows():
		for j in grid.cols():
			if grid.get_cell(i, j).hints() != null:
				h.cells[Vector2i(i, j)] = VIS[rng.randi_range(0, 2)]
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

static func _cellhints_together(rng: RandomNumberGenerator, grid: GridModel) -> void:
	var h := Level.HintVisibility.all_hidden(grid.rows(), grid.cols())
	h.total_water = rng.randf() < 0.5
	for a in [h.row, h.col]:
		RandomHub._vis_array_or(rng, a, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(0, a.size() + 3))
		RandomHub._vis_array_or(rng, a, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(-5, a.size() - 1))
	var cellhints: Array[int] = []
	for i in grid.rows():
		for j in grid.cols():
			if grid.get_cell(i, j).hints() != null:
				cellhints.append(0)
	RandomHub._vis_array_or(rng, cellhints, HintBar.WATER_COUNT_VISIBLE, rng.randi_range(1, cellhints.size() + 2))
	RandomHub._vis_array_or(rng, cellhints, HintBar.WATER_TYPE_VISIBLE, rng.randi_range(1, cellhints.size()))
	for i in grid.rows():
		for j in grid.cols():
			if grid.get_cell(i, j).hints() != null:
				var v: int = cellhints.pop_back()
				h.cells[Vector2i(i, j)] = v if v != 0 else HintBar.WATER_COUNT_VISIBLE
	h.apply_to_grid(grid)
	RandomHub.hide_too_easy_hints(grid)

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

static func _cellhints2_builder(rng: RandomNumberGenerator) -> Generator.Options:
	var opts := Generator.builder().with_cell_hints(rng.randf_range(0.01, 0.25))
	if rng.randf() < 0.35:
		opts.with_diags()
	return opts

static func _cellhints3_builder(rng: RandomNumberGenerator) -> Generator.Options:
	var opts := Generator.builder().with_cell_hints(rng.randf_range(0.01, 0.25))
	if rng.randf() < 0.35:
		opts.with_diags()
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
		Flavor.CellHints1:
			return await l_gen.generate(rng, 7, 7, RandomFlavors._simple_hints, _builder(b.with_cell_hints(0.1)), strategies, [], false)
		Flavor.CellHints2:
			return await l_gen.generate(rng, 5, 6, RandomFlavors._cellhints_together, RandomFlavors._cellhints2_builder, strategies, [], false)
		Flavor.CellHints3:
			return await l_gen.generate(rng, 5, 5, RandomFlavors._everything, _builder(b.with_cell_hints(0.3).with_diags().with_boats()), strategies, [], false)
		Flavor.Liar:
			return await l_gen.generate_with_size(rng, RandomFlavors._liar_size_gen, RandomFlavors._liar_hints, _builder(b), strategies, [], false)
		Flavor.Sudoku:
			return await l_gen.generate(rng, 9, 9, RandomFlavors._sudoku_hints, _builder(b.with_sudoku()), strategies, [], false)
		Flavor.Knight:
			return await l_gen.generate_with_size(rng, RandomFlavors._knight_size_gen, RandomFlavors._knight_hints, _builder(b.with_knights()), strategies, [], false)
		Flavor.Snake:
			return await l_gen.generate_with_size(rng, RandomFlavors._knight_size_gen, RandomFlavors._snake_hints, _builder(b.with_snake()), strategies, []) 
		Flavor.Symbols:
			return await l_gen.generate_with_size(rng, RandomFlavors._symbols_size_gen, RandomFlavors._symbols_hints, RandomFlavors._symbols_builder, strategies, []) 
		Flavor.Mirrors:
			return await l_gen.generate_with_size(rng, RandomFlavors._mirrors_size_gen, RandomFlavors._mirrors_hints, RandomFlavors._mirrors_builder, strategies, [], false)
		_:
			push_error("Unknown flavor %d" % flavor)
			return null
