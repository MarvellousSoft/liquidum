extends Control

enum STATES {MAIN_MENU, LEVEL_HUB}

const CAM_POS = {
	"desktop": {
		"menu": Vector2(1930, 1080),
		"level_hub": Vector2(1930, -1280),
	},
	"mobile": {
		"menu": Vector2(360, 640),
		"level_hub": Vector2(360, -1136),
	},
}
const EPS = .001
const ZOOM_LERP = 4.0
const LEVEL_ZOOM = {
	"desktop": 2.6,
	"mobile": 2.6,
}
const NORMAL_ZOOM = {
	"desktop": 1.0,
	"mobile": 1.0,
}
const ICONS = {
	"fish": preload("res://assets/images/ui/icons/double-fish.png"),
	"turtle": preload("res://assets/images/ui/icons/turtle.png"),
	"shrimp": preload("res://assets/images/ui/icons/shrimp.png"),
}

@onready var Version: Label = %Version
@onready var ProfileButton: Button = $ProfileButton
@onready var Camera = $Camera2D
@onready var LevelHub = $LevelHub
@onready var Settings = $SettingsScreen

var cam_target_zoom = NORMAL_ZOOM.desktop
var cur_state = STATES.MAIN_MENU

func _ready():
	if not SteamManager.enabled:
		$MainButtonsContainer/VBoxContainer/Workshop.disabled = true
	
	cam_target_zoom = NORMAL_ZOOM.mobile if Global.is_mobile else NORMAL_ZOOM.desktop
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	Camera.position = cam_pos.menu
	AudioManager.play_bgm("main")
	
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION


func _process(dt):
	var z = Camera.zoom.x
	if z != cam_target_zoom:
		z = lerp(z, cam_target_zoom, clamp(ZOOM_LERP*dt, 0.0, 1.0))
		if abs(z - cam_target_zoom) <= EPS:
			z = cam_target_zoom
		Camera.zoom.x = z
		Camera.zoom.y = z


func _unhandled_input(event):
	if event.is_action_pressed("return"):
		if cur_state == STATES.MAIN_MENU:
			Settings.toggle_pause()
		elif cur_state == STATES.LEVEL_HUB and not LevelHub.level_focused:
			_on_back_button_pressed()


func _enter_tree() -> void:
	call_deferred("update_level_hub")
	call_deferred("update_profile_button")


func update_level_hub():
	LevelHub.update_sections()


func update_profile_button() -> void:
	ProfileButton.icon = ICONS[FileManager.current_profile]


func _on_editor_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var editor_hub = preload("res://game/editor_menu/EditorHub.tscn").instantiate()
	TransitionManager.push_scene(editor_hub)


func _on_profile_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var profile := preload("res://game/profile_menu/ProfileScreen.tscn").instantiate()
	TransitionManager.push_scene(profile)

func _on_workshop_pressed():
	AudioManager.play_sfx("button_pressed")
	var workshop := preload("res://game/workshop_menu/WorkshopMenu.tscn").instantiate()
	TransitionManager.push_scene(workshop)


func _on_exit_button_pressed():
	AudioManager.play_sfx("button_pressed")
	if ConfirmationScreen.start_confirmation(&"EXIT_CONFIRMATION"):
		if await ConfirmationScreen.pressed:
			Global.exit_game()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")

func _on_play_pressed():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	AudioManager.play_sfx("button_pressed")
	Camera.position = cam_pos.level_hub
	cur_state = STATES.LEVEL_HUB


func _on_back_button_pressed():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	AudioManager.play_sfx("button_back")
	Camera.position = cam_pos.menu
	cur_state = STATES.MAIN_MENU


func _on_level_hub_enable_focus(pos, _my_section):
	Camera.position = pos
	cam_target_zoom = LEVEL_ZOOM.mobile if Global.is_mobile else LEVEL_ZOOM.desktop


func _on_level_hub_disable_focus():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	Camera.position = cam_pos.level_hub
	cam_target_zoom = NORMAL_ZOOM.mobile if Global.is_mobile else NORMAL_ZOOM.desktop


func _on_random_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.push_scene(preload("res://game/random_menu/RandomHub.tscn").instantiate())


func _on_credits_button_pressed() -> void:
	TransitionManager.push_scene(Global.load_no_mobile("res://game/credits/CreditsScreen").instantiate())
