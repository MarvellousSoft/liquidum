extends Control

signal enable_focus(pos : Vector2, extra : bool)
signal disable_focus()

@onready var Sections = %Sections

var level_focused := false
var section_focused := -1
var level_to_unlock = -1
var section_to_unlock = -1
var last_button_to_endless: LevelButton = null
## Load extra levels instead of regular campaign levels
@export var extra_levels := false

func _ready() -> void:
	if extra_levels:
		while Sections.get_child_count() > 0:
			var c := Sections.get_child(Sections.get_child_count() - 1)
			Sections.remove_child(c)
			c.queue_free()
	update_sections()

func _process(dt):
	var idx = 1
	for section in Sections.get_children():
		Global.alpha_fade_node(dt, section, not level_focused or idx == section_focused, 4.0, false)
		idx += 1


func _enter_tree() -> void:
	SteamManager.overlay_toggled.connect(_on_overlay_toggled)
	Profile.unlock_everything_changed.connect(_on_unlock_changed)
	Global.dev_mode_toggled.connect(_on_unlock_changed)
	Profile.dark_mode_toggled.connect(_on_dark_mode_toggled)
	_on_dark_mode_toggled(Profile.get_option("dark_mode"))
	if extra_levels and Global.is_mobile and AdManager.payment != null:
		AdManager.payment.dlc_purchased.connect(_on_dlc_purchased)
	check_unlocks()


func _exit_tree() -> void:
	Profile.dark_mode_toggled.disconnect(_on_dark_mode_toggled)
	Global.dev_mode_toggled.disconnect(_on_unlock_changed)
	Profile.unlock_everything_changed.disconnect(_on_unlock_changed)
	SteamManager.overlay_toggled.disconnect(_on_overlay_toggled)
	if extra_levels and Global.is_mobile and AdManager.payment != null:
		AdManager.payment.dlc_purchased.disconnect(_on_dlc_purchased)

func _on_dark_mode_toggled(on: bool) -> void:
	# Always desktop theme because we scale these in mobile
	if on:
		theme = Global.THEME.desktop.dark
	else:
		theme = Global.THEME.desktop.normal

func _on_dlc_purchased(_id: String) -> void:
	update_sections()

func _on_unlock_changed(on: bool) -> void:
	if not on and get_focused_section() != null:
		get_focused_section().unfocus()
	update_sections()

func _on_overlay_toggled(on: bool) -> void:
	if not on:
		update_sections()

func update_sections() -> void:
	var level_lister: LevelLister = ExtraLevelLister as LevelLister if extra_levels else CampaignLevelLister as LevelLister
	var count: int = level_lister.count_all_game_sections()
	while Sections.get_child_count() < count:
		var c := preload("res://game/levelhub/LevelSection.tscn").instantiate()
		Sections.add_child(c)
		c.enable_focus.connect(_on_level_section_enable_focus)
		c.disable_focus.connect(_on_level_section_disable_focus)
		if extra_levels:
			if not c.is_connected("loaded_endless", _on_loaded_endless):
					c.loaded_endless.connect(_on_loaded_endless)
	var idx := 1
	for section in Sections.get_children():
		section.set_number(idx)
		var unlocked := level_lister.get_max_unlocked_level(idx)
		if level_lister.section_disabled(idx):
			unlocked = 0
		elif Global.is_dev_mode() or Profile.get_option("unlock_everything"):
			unlocked = level_lister.count_section_levels(idx)
		section.set_section_name(level_lister.section_name(idx))
		if unlocked == 0:
			section.disable()
		else:
			section.enable()
			section.setup(self, idx, unlocked, extra_levels)
		if extra_levels:
			section.setup_dlc_button()
		else:
			section.delete_dlc_button()
		idx += 1

func _on_loaded_endless(button: LevelButton) -> void:
	last_button_to_endless = button

func check_unlocks() -> void:
	#Unlock a new level
	if level_to_unlock != -1:
		var section = Sections.get_child(section_to_unlock - 1)
		section.disable_level(level_to_unlock)
		await TransitionManager.transition_finished
		section.unlock_level(level_to_unlock)
	#Unlock a new section
	elif section_to_unlock != -1:
		var section = Sections.get_child(section_to_unlock - 1)
		section.disable()
		await TransitionManager.transition_finished
		#Unfocus previous sections
		get_focused_section().unfocus()
		await get_tree().create_timer(.5).timeout
		section.unlock()
	level_to_unlock = -1
	section_to_unlock = -1


func prepare_to_unlock_level(section, level):
	section_to_unlock = section
	level_to_unlock = level


func unlock_section(prev_section):
	level_to_unlock = -1
	section_to_unlock = prev_section + 1


func _on_level_section_enable_focus(pos, my_section, extra):
	level_focused = true
	section_focused = my_section
	enable_focus.emit(pos, extra)


func _on_level_section_disable_focus():
	disable_focus.emit()
	#Wait a frame to any back button event wont also trigger on level hub
	await get_tree().process_frame
	level_focused = false

func get_focused_section():
	if not level_focused:
		return null
	return Sections.get_child(section_focused - 1)

func _play_new_endless() -> void:
	if last_button_to_endless == null:
		TransitionManager.pop_scene()
	else:
		await last_button_to_endless.gen_and_load_endless()
