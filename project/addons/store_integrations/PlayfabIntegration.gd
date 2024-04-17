
class_name PlayFabIntegration
extends StoreIntegration

signal uploaded_leaderboard()

var playfab: PlayFab

var ld_mapping := {}

static func available() -> bool:
	return SteamIntegration.available() or GooglePlayGameServices.enabled

func _ready() -> void:
	if not PlayFabManager.is_node_ready():
		print("Waiting for PlayFab initialization")
		await PlayFabManager.ready
	playfab = PlayFabManager.client
	playfab.json_parse_error.connect(_on_err)
	playfab.api_error.connect(_on_err)
	playfab.server_error.connect(_on_err)
	playfab.logged_in.connect(_logged_in, Object.CONNECT_DEFERRED)
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
				_on_google_game_services_login,
			)
	else:
		print("Playfab login already saved")

func _on_err(err) -> void:
	print("Some error: %s" % [err])
	assert(false) # Open debugged in debug mode

func _logged_in(res) -> void:
	print("Logged in to PlayFab: %s!" % [authenticated()])

func _on_steam_login(result: Dictionary, ticket_id: int) -> void:
	SteamManager.steam.cancelAuthTicket(ticket_id)
	var login_result = LoginResult.new()
	login_result.from_dict(result["data"], login_result)
	playfab.logged_in.emit(login_result)

func _on_google_game_services_login(result) -> void:
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

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> void:
	var id: String = ld_mapping.get(leaderboard_id, "")
	if id == "" or not authenticated():
		return
	playfab.post_dict_auth(
		{
			Statistics = [{
				StatisticName = id,
				Value = score,
			}]
		},
		"/Client/UpdatePlayerStatistics",
		PlayFab.AUTH_TYPE.SESSION_TICKET,
		_on_leaderboard_upload,
	)
	# Fire and forget while we are testing
	# await uploaded_leaderboard

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
