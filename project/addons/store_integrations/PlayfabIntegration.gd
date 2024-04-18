
class_name PlayFabIntegration
extends StoreIntegration

signal uploaded_leaderboard()
signal downloaded_leaderboard(res: Dictionary)

var playfab: PlayFab

var ld_mapping := {}

static func available() -> bool:
	return SteamIntegration.available() or GooglePlayGameServices.enabled or AppleIntegration.available()

func _try_authenticate() -> void:
	if not authenticated():
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
			playfab.post_dict(
				{
					TitleId = PlayFabManager.title_id,
					CreateAccount = true,
					SteamTicket = buffer.hex_encode(),
					TicketIsServiceSpecific = false,
				},
				"/Client/LoginWithSteam",
				_on_steam_login.bind(ticket.id),
			)
		if GooglePlayGameServices.enabled:
			print("Will try to authenticate through Play Services")
			if not GooglePlayGameServices.auth_done:
				print("Waiting for auth")
				await GooglePlayGameServices.sign_in_user_authenticated
			GooglePlayGameServices.sign_in_request_server_side_access("530621401925-gbemotmd7i0q0qeurk4vjni6l1enfm5r.apps.googleusercontent.com", false)
			var res = await GooglePlayGameServices.sign_in_requested_server_side_access
			playfab.post_dict(
				{
					TitleId = PlayFabManager.title_id,
					CreateAccount = true,
					ServerAuthCode = res,
				},
				"/Client/LoginWithGooglePlayGamesServices",
				_on_simple_login,
			)
		if AppleIntegration.available():
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
						playfab.post_dict(
							{
								TitleId = PlayFabManager.title_id,
								CreateAccount = true,
								PlayerId = ev["player_id"],
								PublicKeyUrl = ev["public_key_url"],
								Signature = ev["signature"],
								Salt = ev["salt"],
								Timestamp = ev["timestamp"],
							},
							"/Client/LoginWithGameCenter",
							_on_simple_login,
						)
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
	if err.get("error") == "NotAuthenticated":
		print("Not authenticated to Playfab, trying to login again.")
		PlayFabManager.forget_login()
		await _try_authenticate()
	assert(false) # Open debugged in debug mode

func _logged_in(res) -> void:
	print("Logged in to PlayFab: %s!" % [authenticated()])

func _on_steam_login(result, ticket_id: int) -> void:
	SteamManager.steam.cancelAuthTicket(ticket_id)
	_on_simple_login(result)

func _on_simple_login(result) -> void:
	if result is Dictionary and result.has("data"):
		var login_result = LoginResult.new()
		login_result.from_dict(result["data"], login_result)
		playfab.logged_in.emit(login_result)
	else:
		print("Weird login result: %s" % [result])

func authenticated() -> bool:
	return PlayFabManager.client_config.is_logged_in()

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.playfab_id != "":
			ld_mapping[ld.id] = ld.playfab_id

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
	playfab.post_dict_auth(
		{
			Statistics = [{
				StatisticName = id,
				Value = int(score),
			}]
		},
		"/Client/UpdatePlayerStatistics",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		_on_leaderboard_upload,
	)
	# Fire and forget while we are testing
	# await uploaded_leaderboard

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> void:
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	await leaderboard_upload_score(leaderboard_id, minf(time_secs, RecurringMarathon.MAX_TIME - 1) + minf(mistakes, 1000) * RecurringMarathon.MAX_TIME, keep_best, steam_details)

func _on_leaderboard_upload(res: Variant) -> void:
	if res is Dictionary and res.get("status", "") == "OK":
		print("Playfab leaderboard upload success")
		uploaded_leaderboard.emit()
	else:
		print("Playfab leaderboard upload failure")
		assert(false)

func leaderboard_show(_leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
	await null

func achievement_set(_ach_id: String, _steps: int, _total_steps: int) -> void:
	await null

func achievement_show_all() -> void:
	await null

func _on_leaderboard_downloaded(res) -> void:
	downloaded_leaderboard.emit(res)

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
		},
	}
	if version != -1:
		req["Version"] = version
	playfab.post_dict_auth(
		req,
		"/Client/GetLeaderboard",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		_on_leaderboard_downloaded,
	)
	var res: Dictionary = await downloaded_leaderboard
	if res.status != "OK":
		return null
	var data := StoreIntegrations.LeaderboardData.new()
	var my_id := PlayFabManager.client_config.master_player_account_id
	for raw_entry in res.data.Leaderboard:
		var entry := StoreIntegrations.LeaderboardEntry.new()
		entry.mistakes = int(raw_entry.StatValue) / RecurringMarathon.MAX_TIME
		entry.secs = int(raw_entry.StatValue) % RecurringMarathon.MAX_TIME
		entry.rank = int(raw_entry.Position) + 1
		var display_name: String = raw_entry.get("DisplayName", "")
		if raw_entry.PlayFabId == my_id:
			data.has_self = true
		for acc in raw_entry.Profile.LinkedAccounts:
			if acc.get("Platform", "") == "Steam":
				entry.extra_data["steam_id"] = int(acc.PlatformUserId)
				if display_name == "":
					display_name = acc.get("Username", "")
		if display_name == "":
			display_name = str(raw_entry.PlayFabId)
		entry.display_name = display_name
		data.entries.append(entry)
	return data
	
