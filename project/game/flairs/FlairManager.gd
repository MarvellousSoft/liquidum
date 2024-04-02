class_name FlairManager

static func get_current_flair():
	var list = get_flair_list()
	if list.size() > 0:
		return list[get_selected_flair_idx()]
	return null


static func get_flair_amount():
	return get_flair_list().size()


static func _monthly_flairs() -> Array[SelectableFlair]:
	var S := TranslationServer.get_translation_object(TranslationServer.get_locale())
	var arr: Array[SelectableFlair] = []
	var data := UserData.current()
	var cur_year := 2024
	var cur_month := 1
	var rng := RandomNumberGenerator.new()
	for i in data.monthly_good_dailies.size():
		cur_month += 1
		if cur_month == 13:
			cur_month = 1
			cur_year += 1
		if data.monthly_good_dailies[i] >= 15:
			rng.seed = RandomHub.consistent_hash("%d-%d" % [cur_month, cur_year])
			arr.append(SelectableFlair.new(
				"pro",
				Color.from_hsv(rng.randf(), 0.663, 0.804, 1),
				S.tr("MONTHLY_FLAIR_DESC").format({
					month=S.tr("MONTH_%02d" % [cur_month]),
					year=cur_year,
				})
			))
	return arr


static func get_flair_list() -> Array[SelectableFlair]:
	var arr: Array[SelectableFlair] = []
	if SteamManager.enabled and RecurringMarathon.DEV_IDS.has(SteamManager.steam.getSteamID()):
		arr.append(SelectableFlair.new(
			"dev",
			Color(0.0784314, 0.364706, 0.529412, 1),
			"Vc é um desenvolvedor pô",
		))
	arr.append_array(_monthly_flairs())
	return arr


static func get_selected_flair_idx() -> int:
	return UserData.current().selected_flair


static func set_selected_flair_idx(idx: int) -> void:
	UserData.current().selected_flair = idx
