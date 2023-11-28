extends Control

const CAM_POS = {
	"menu": Vector2(1930, 1080),
	"level_hub": Vector2(1930, -1280),
}
const EPS = .001
const ZOOM_LERP = 4.0
const LEVEL_ZOOM = 2.6
const NORMAL_ZOOM = 1.0

@onready var Version: Label = $Version
@onready var ProfileButton: Button = $ProfileButton
@onready var Camera = $Camera2D

var cam_target_zoom = NORMAL_ZOOM

func _ready():
	randomize()
	FileManager.load_game()
	
	Camera.position = CAM_POS.menu
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


func _enter_tree() -> void:
	#call_deferred("update_open_levels")
	call_deferred("update_profile_button")


func update_profile_button() -> void:
	ProfileButton.text = "%s: %s" % [tr("PROFILE"), FileManager.current_profile]


func _on_editor_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var editor_hub = preload("res://game/editor_menu/EditorHub.tscn").instantiate()
	TransitionManager.push_scene(editor_hub)


func _on_profile_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var profile := preload("res://game/profile_menu/ProfileScreen.tscn").instantiate()
	TransitionManager.push_scene(profile)


func _on_exit_button_pressed():
	AudioManager.play_sfx("button_pressed")
	if ConfirmationScreen.start_confirmation("EXIT_CONFIRMATION"):
		if await ConfirmationScreen.pressed:
			get_tree().quit()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_play_pressed():
	AudioManager.play_sfx("button_pressed")
	Camera.position = CAM_POS.level_hub


func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	Camera.position = CAM_POS.menu


func _on_level_hub_enable_focus(pos, _my_section):
	Camera.position = pos
	cam_target_zoom = LEVEL_ZOOM


func _on_level_hub_disable_focus():
	Camera.position = CAM_POS.level_hub
	cam_target_zoom = NORMAL_ZOOM
