@icon("res://addons/godot-playfab/icon.png")

extends RefCounted
class_name PlayFabClientConfig

# Timeout for the sesion token
const TOKEN_TIMEOUT = 23 * 3600

## The Client Session ticket. Used for /Client API
var session_ticket: String : set = _set_session_ticket

## The Master Player Account ID, aka "PlayFab ID"
var master_player_account_id: String

## Object holding the Entity Token, as well as the EntityKey (ID, Type) of the logged in Entity (usually title_player_account)
var entity_token: EntityTokenResponse = EntityTokenResponse.new()

# Last Login timestamp - when tokens were refreshed
var login_timestamp = 0

# Checks whether the account is considered logged in
func is_logged_in() -> bool:
	if session_ticket.is_empty() || is_login_token_expired():
		return false

	return true


# Validates whether the login token has expired (based checked time)
func is_login_token_expired() -> bool:
	var elapsed_time = Time.get_unix_time_from_system() - login_timestamp

	if elapsed_time < 0 || elapsed_time > TOKEN_TIMEOUT:
		return true

	return false


# Sets the session_ticket and updates the login_timestamp
func _set_session_ticket(value: String):
	login_timestamp = int(Time.get_unix_time_from_system())
	session_ticket = value

func _fields() -> Array:
	return ["session_ticket", "master_player_account_id", "entity_token", "login_timestamp"]
