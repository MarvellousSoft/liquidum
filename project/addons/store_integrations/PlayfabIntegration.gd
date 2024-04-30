
class_name PlayFabIntegration
extends StoreIntegration

signal uploaded_leaderboard()

var playfab: PlayFab

var ld_mapping := {}
var sort_method := {}

static func available() -> bool:
	if Global.is_demo:
		return false
	return SteamIntegration.available() or GooglePlayGameServices.enabled or AppleIntegration.available() or OS.get_name() == "iOS"

func _try_authenticate() -> void:
	if not authenticated():
		var req := {
			TitleId = PlayFabManager.title_id,
			CreateAccount = true,
		}
		if SteamManager.enabled:
			print("Will try to authenticate through Steam")
			# Can't use getAuthTicketForWebApi because we're using an old GodotSteam tied to 4.1.3
			var ticket: Dictionary = SteamManager.steam.getAuthSessionTicket()
			var res: Array = await SteamManager.steam.get_auth_session_ticket_response
			assert(res[0] == ticket.id)
			if res[1] != SteamManager.steam.RESULT_OK:
				print("Failed to get ticket: %s" % [res])
				return
			var buffer: PackedByteArray = ticket.buffer
			buffer.resize(ticket.size)
			req.merge({
				SteamTicket = buffer.hex_encode(),
				TicketIsServiceSpecific = false,
			})
			playfab.post_dict(
				req,
				"/Client/LoginWithSteam",
				_on_steam_login.bind(ticket.id, null),
			)
		elif GooglePlayGameServices.enabled:
			print("Will try to authenticate through Play Services")
			if not GooglePlayGameServices.auth_done:
				print("Waiting for auth")
				await GooglePlayGameServices.sign_in_user_authenticated
			GooglePlayGameServices.sign_in_request_server_side_access("530621401925-gbemotmd7i0q0qeurk4vjni6l1enfm5r.apps.googleusercontent.com", false)
			var res = await GooglePlayGameServices.sign_in_requested_server_side_access
			req.merge({
				ServerAuthCode = res,
			})
			playfab.post_dict(
				req,
				"/Client/LoginWithGooglePlayGamesServices",
				_on_simple_login.bind(null)
			)
		# This is not working for some reason
		elif AppleIntegration.available() and false:
			print("Will try to authenticate with Game Center")
			var impl: AppleIntegration
			for impl2 in StoreIntegrations.impls:
				if impl2 is AppleIntegration:
					impl = impl2
					break
			if impl != null:
				if not await impl._try_authenticate():
					print("Could not authenticate with Game Center")
				else:
					impl.apple.request_identity_verification_signature()
					var ev: Dictionary = await impl.event
					if ev["type"] != "identity_verification_signature" or ev["result"] != "ok":
						print("Could not authenticate with Game Center: Failed to get signature")
					else:
						req.merge({
							PlayerId = ev.player_id,
							PublicKeyUrl = ev.public_key_url,
							Signature = ev.signature,
							Salt = ev.salt,
							Timestamp = ev.timestamp,
						})
						playfab.post_dict(
							req,
							"/Client/LoginWithGameCenter",
							_on_simple_login.bind(null),
						)
		elif OS.get_name() == "iOS":
			print("Authenticating with iOS id")
			req.merge({
				DeviceId = OS.get_unique_id(),
				DeviceModel = OS.get_model_name(),
			})
			print("Will call with %s" % [req])
			playfab.post_dict(
				req,
				"/Client/LoginWithIOSDeviceID",
				_on_simple_login.bind(null),
			)
		else:
			print("PlayFab is not sure how to authenticate.")
	else:
		print("Playfab login already saved")

func _ready() -> void:
	if not PlayFabManager.is_node_ready():
		print("Waiting for PlayFab initialization")
		await PlayFabManager.ready
	playfab = PlayFabManager.client
	playfab.json_parse_error.connect(_on_err)
	playfab.api_error.connect(_on_err)
	playfab.server_error.connect(_on_err)
	playfab.logged_in.connect(_logged_in, Object.CONNECT_DEFERRED)
	await _try_authenticate()


func _on_err(err) -> void:
	var err_str: String = str(err)
	if err_str.begins_with("<RefCounted"):
		err_str = ""
		for prop in err.get_property_list():
			err_str += "%s: %s, " % [prop.name, err.get(prop.name)]
	print("Some error: %s" % [err_str])
	if err is Dictionary and err.get("error") == "NotAuthenticated":
		print("Not authenticated to Playfab, trying to login again.")
		PlayFabManager.forget_login()
		await _try_authenticate()
	assert(false) # Open debugged in debug mode

func _logged_in(res) -> void:
	print("Logged in to PlayFab: %s!" % [authenticated()])

func _on_steam_login(result, ticket_id: int, display_name_getter) -> void:
	SteamManager.steam.cancelAuthTicket(ticket_id)
	_on_simple_login(result, display_name_getter)

func _on_simple_login(result, display_name_getter) -> void:
	if result is Dictionary and result.has("data"):
		var login_result = LoginResult.new()
		login_result.from_dict(result["data"], login_result)
		playfab.logged_in.emit(login_result)
		if login_result.NewlyCreated and display_name_getter != null:
			var display_name: String = await display_name_getter.call()
			playfab.post_dict_auth(
				{
					DisplayName = display_name,
				},
				"/Client/UpdateUserTitleDisplayName",
				PlayFab.AUTH_TYPE.SESSION_TICKET,
				_generic_request,
			)
	else:
		print("Weird login result: %s" % [result])

func _generic_request(_res) -> void:
	pass

func authenticated() -> bool:
	return PlayFabManager.client_config.is_logged_in()

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.playfab_id != "":
			ld_mapping[ld.id] = ld.playfab_id
			sort_method[ld.id] = ld.sort_method

func leaderboard_create_if_not_exists(_leaderboard_id: String, _sort_method: StoreIntegrations.SortMethod) -> void:
	await null

func _get_ld_mapping(id: String) -> String:
	if ld_mapping.has(id):
		return ld_mapping[id]
	elif id.begins_with("daily_"):
		return "daily"
	elif id.begins_with("weekly_"):
		return "weekly"
	return ""

func _get_ld_version(id: String) -> int:
	if ld_mapping.has(id):
		return -1
	elif id.begins_with("daily_"):
		# Getting version from day
		var day_unix := Time.get_unix_time_from_datetime_string(id.substr(6))
		return (day_unix - Time.get_unix_time_from_datetime_string("2024-04-16")) / (24 * 60 * 60)
	elif id.begins_with("weekly_"):
		var monday_unix := Time.get_unix_time_from_datetime_string(id.substr(6))
		return (monday_unix - Time.get_unix_time_from_datetime_string("2024-04-15")) / (7 * 24 * 60 * 60)
	return -1

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> void:
	var id := _get_ld_mapping(leaderboard_id)
	if id == "" or not authenticated():
		return
	var value := int(score)
	if sort_method.get(leaderboard_id, StoreIntegrations.SortMethod.SmallestFirst) == StoreIntegrations.SortMethod.SmallestFirst:
		value = -value
	playfab.post_dict_auth(
		{
			Statistics = [{
				StatisticName = id,
				Value = value,
			}]
		},
		"/Client/UpdatePlayerStatistics",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		_on_leaderboard_upload,
	)
	# Fire and forget while we are testing
	# await uploaded_leaderboard
	await null

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> void:
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	await leaderboard_upload_score(leaderboard_id, minf(time_secs, RecurringMarathon.MAX_TIME - 1) + minf(mistakes, 1000) * RecurringMarathon.MAX_TIME, keep_best, steam_details)

func _on_leaderboard_upload(res: Variant) -> void:
	uploaded_leaderboard.emit()
	if res is Dictionary and res.get("status", "") == "OK":
		print("Playfab leaderboard upload success")
	else:
		print("Playfab leaderboard upload failure")
		assert(false)

func leaderboard_show(_leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
	await null

func achievement_set(_ach_id: String, _steps: int, _total_steps: int) -> void:
	await null

func achievement_show_all() -> void:
	await null

class LeaderboardAndFlairs:
	signal all_downloaded
	var lds = null
	var flairs = null
	func _on_leaderboard_downloaded(res) -> void:
		lds = res
		check_complete()
	func _on_flairs_downloaded(res) -> void:
		flairs = res
		check_complete()
	func check_complete() -> void:
		if lds != null and flairs != null:
			all_downloaded.emit()

func update_flair_if_outdated(id_to_flair: Dictionary) -> void:
	var cur_flair := FlairManager.get_current_flair()
	var cur_flair_int: int = cur_flair.to_steam_flair().encode_to_int() if cur_flair != null else -1
	var ld_flair: SteamFlair = id_to_flair.get(PlayFabManager.client_config.master_player_account_id, null)
	var ld_flair_int: int = -1 if ld_flair == null else ld_flair.encode_to_int()
	if cur_flair_int != ld_flair_int:
		id_to_flair[PlayFabManager.client_config.master_player_account_id] = SteamFlair.decode_from_int(cur_flair_int)
		await FlairPicker.save_flair_to_playfab()

func leaderboard_download_completion(leaderboard_id: String, start: int, count: int) -> StoreIntegrations.LeaderboardData:
	var id := _get_ld_mapping(leaderboard_id)
	if id == "" or not authenticated():
		return null
	var version := _get_ld_version(leaderboard_id)
	var req := {
		StartPosition = start - 1,
		MaxResultsCount = mini(count, 100),
		StatisticName = id,
		ProfileConstraints = {
			ShowLinkedAccounts = true,
			ShowAvatarUrl = true,
			ShowDisplayName = true,
		},
	}
	if version != -1:
		req["Version"] = version
	var res := LeaderboardAndFlairs.new()
	playfab.post_dict_auth(
		req,
		"/Client/GetLeaderboard",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		res._on_leaderboard_downloaded,
	)
	# TODO: If we get too many players this has to change
	playfab.post_dict_auth(
		{
			StartPosition = 0,
			MaxResultsCount = 100,
			StatisticName = "flair",
		},
		"/Client/GetLeaderboard",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		res._on_flairs_downloaded,
	)
	await res.all_downloaded
	var negate: bool = sort_method.get(leaderboard_id, StoreIntegrations.SortMethod.SmallestFirst) == StoreIntegrations.SortMethod.SmallestFirst
	if res.lds.status != "OK":
		print("Failed to download leaderboard %s: %s" % [leaderboard_id, res.lds])
		return null
	var id_to_flair := {}
	if res.flairs.status == "OK":
		for raw_entry in res.flairs.data.Leaderboard:
			id_to_flair[raw_entry.PlayFabId] = SteamFlair.decode_from_int(int(raw_entry.StatValue))
	else:
		push_warning("Invalid flairs response: %s" % [res.flairs])
	update_flair_if_outdated(id_to_flair)
	var data := StoreIntegrations.LeaderboardData.new()
	var my_id := PlayFabManager.client_config.master_player_account_id
	var rng := RandomNumberGenerator.new()
	for raw_entry in res.lds.data.Leaderboard:
		var entry := StoreIntegrations.LeaderboardEntry.new()
		var value: int = -int(raw_entry.StatValue) if negate else int(raw_entry.StatValue)
		entry.mistakes = value / RecurringMarathon.MAX_TIME
		entry.secs = value % RecurringMarathon.MAX_TIME
		entry.rank = int(raw_entry.Position) + 1
		if id_to_flair.has(raw_entry.PlayFabId):
			entry.extra_data["flair"] = id_to_flair[raw_entry.PlayFabId]
		var display_name: String = raw_entry.Profile.get("DisplayName", "")
		if raw_entry.PlayFabId == my_id:
			data.has_self = true
		if raw_entry.Profile.get("AvatarUrl", "") != "":
			entry.extra_data["avatar_url"] = raw_entry.Profile.AvatarUrl
		for acc in raw_entry.Profile.LinkedAccounts:
			if acc.get("Platform", "") == "Steam":
				entry.extra_data["steam_id"] = int(acc.PlatformUserId)
			if acc.get("Platform", "") == "GooglePlayGames":
				entry.extra_data["android_id"] = acc.PlatformUserId
			if acc.get("Platform", "") == "IOSDevice":
				entry.extra_data["ios_device"] = acc.PlatformUserId
			if display_name == "":
				display_name = acc.get("Username", "")
		if display_name == "":
			display_name = NameGenerator.get_name(rng, str(raw_entry.PlayFabId))
		entry.display_name = display_name
		data.entries.append(entry)
	return data
	
