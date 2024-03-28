@tool
extends EditorPlugin

const AUTOLOAD_NAME = "StoreIntegrations"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/store_integrations/StoreIntegrationsAPI.gd")



func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
