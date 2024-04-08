class_name FlairManager

enum FlairId {
	Dev = 0,
	Streak30,
	Insane100,
	MainCampaign,
	Dlc,
	MarvInc,
	Functional,
	# Pro ids start at 10000, on 2024-01, and increment 1 by month
	ProStart = 10000,
}


static func get_flair_amount() -> int:
	return get_flair_list().size()

static func create_flair(id: int) -> SelectableFlair:
	match id:
		-1:
			return null
		FlairId.Dev:
			return SelectableFlair.new(
				FlairId.Dev,
				"dev",
				Color.RED,
				"DEVELOPER_FLAIR_DESCRIPTION",
			)
		FlairId.Streak30:
			return SelectableFlair.new(
				FlairId.Streak30,
				"30🔥",
				Color.ORANGE_RED,
				"FLAIR_30_STREAK_DESC",
			)
		FlairId.Insane100:
			return SelectableFlair.new(
				FlairId.Insane100,
				"100",
				Color.BLACK,
				"FLAIR_100_DESC",
			)
		FlairId.MainCampaign:
			return SelectableFlair.new(
				FlairId.MainCampaign,
				"won",
				Color.GREEN,
				"FLAIR_WON_DESC",
			)
		FlairId.Dlc:
			return SelectableFlair.new(
					FlairId.Dlc,
					"❤",
					Color.HOT_PINK,
					"FLAIR_DLC_DESC",
				)
		FlairId.MarvInc:
			return SelectableFlair.new(
				FlairId.MarvInc,
				"inc",
				Color.GREEN,
				"FLAIR_INC_DESC",
			)
		FlairId.Functional:
			return SelectableFlair.new(
				FlairId.Functional,
				"λ",
				Color.GRAY,
				"FLAIR_FUNCTIONAL_DESC",
			)
	if id >= FlairId.ProStart:
		var year: int = ((id - FlairId.ProStart) / 12) + 2024
		var month: int = ((id - FlairId.ProStart) % 12) + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = RandomHub.consistent_hash("%d-%d" % [month, year])
		var S := TranslationServer.get_translation_object(TranslationServer.get_locale())
		return SelectableFlair.new(
			id,
			"pro",
			Color.from_hsv(rng.randf(), 0.663, 0.804, 1),
			S.tr("MONTHLY_FLAIR_DESC").format({
				month=S.tr("MONTH_%02d" % [month]),
				year=year,
			})
		)
	push_warning("Unknown flair: %d" % [id])
	return null

static func _monthly_flairs() -> Array[SelectableFlair]:
	var arr: Array[SelectableFlair] = []
	var data := UserData.current()
	var cur_year := 2024
	var cur_month := 1
	for i in data.monthly_good_dailies.size():
		cur_month += 1
		if cur_month == 13:
			cur_month = 1
			cur_year += 1
		if data.monthly_good_dailies[i] >= 15:
			var id: int = FlairId.ProStart + (cur_year - 2024) * 12 + (cur_month - 2)
			arr.append(create_flair(id))
	return arr

# Memoize for 60 seconds
static var _list: Array[SelectableFlair] = []
static var _last_update: int = -1000000

static func get_flair_list() -> Array[SelectableFlair]:
	if _last_update >= Time.get_ticks_msec() - 60000:
		return _list
	var data := UserData.current()
	var arr: Array[SelectableFlair] = []
	if SteamManager.enabled and RecurringMarathon.DEV_IDS.has(SteamManager.steam.getSteamID()):
		arr.append(create_flair(FlairId.Dev))
	arr.append_array(_monthly_flairs())
	if data.best_streak[RecurringMarathon.Type.Daily] >= 30:
		arr.append(create_flair(FlairId.Streak30))
	if data.random_levels_completed[RandomHub.Difficulty.Insane] >= 100:
		arr.append(create_flair(FlairId.Insane100))
	if CampaignLevelLister.all_campaign_levels_completed():
		arr.append(create_flair(FlairId.MainCampaign))
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		if not ExtraLevelLister.is_free(extra_section) and not ExtraLevelLister.section_disabled(extra_section):
			arr.append(create_flair(FlairId.Dlc))
			break
		extra_section += 1
	if SteamManager.enabled and Steam.isSubscribedApp(827940):
		arr.append(create_flair(FlairId.MarvInc))
	if SteamManager.enabled and Steam.isSubscribedApp(1636730):
		arr.append(create_flair(FlairId.Functional))
	_list = arr
	return _list

static func get_current_flair() -> SelectableFlair:
	var selected_id := UserData.current().selected_flair
	var list := get_flair_list()
	if list.size() > 0 and selected_id != -1:
		for flair in list:
			if flair.id == selected_id:
				return flair
		# Not a valid flair, selecting the first valid flair
		var first = list.front()
		set_selected_flair_id(first.id)
		return first
	else:
		return null

static func set_selected_flair_id(id: int) -> void:
	UserData.current().selected_flair = id
	UserData.save()
