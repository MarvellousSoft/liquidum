extends CanvasLayer

const COOLDOWN = 0.15

var default_color = Color(1.0,0.416,0.416)
var default_width = 15
var current_line
var active := false
var eraser_mode := false
var erasing := false
var cooldown := 0.0

func _process(dt):
	if cooldown > 0.0:
		cooldown = max(cooldown - dt, 0.0)

func _input(event):
	if not active or cooldown > 0.0 or not %Lines.visible:
		return
	#For debugging
#	if event is InputEventKey and event.pressed and event.keycode == KEY_5:
#		set_eraser_mode(not eraser_mode)
	if not eraser_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_new_line()
			else:
				_stop_line()
		elif event is InputEventMouseMotion:
			_increase_line()
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			erasing = event.pressed
		elif event is InputEventMouseMotion:
			if erasing:
				_try_to_erase(%Lines.get_local_mouse_position(), %Lines.get_local_mouse_position() + event.relative)


func apply_cooldown():
	erasing = false
	_stop_line()
	cooldown += COOLDOWN


func set_default_width(width : Color):
	default_width = width


func set_default_color(color : Color):
	default_color = color


func set_eraser_mode(value : bool):
	eraser_mode = value


func set_visibility(status : bool):
	%Lines.visible = status


func clear():
	for child in %Lines.get_children():
		child.queue_free()


func import(data : Array):
	clear()
	for line_data in data:
		var line = _create_line(line_data.color, line_data.width, line_data.points)
		%Lines.add_child(line)


func export():
	var data = []
	for line in %Lines.get_children():
		data.append({
			"points" : line.points,
			"color" : line.default_color,
			"width" : line.width,
		})
	return data



func _start_new_line():
	current_line = _create_line(default_color, default_width)
	%Lines.add_child(current_line)
	current_line.add_point(%Lines.get_local_mouse_position())


func _stop_line():
	current_line = null


func _increase_line():
	if not current_line:
		return
	current_line.add_point(%Lines.get_local_mouse_position())


func _try_to_erase(from, to):
	var to_delete = []
	for line in %Lines.get_children():
		var idx = 0
		while idx + 1 < line.points.size():
			if Geometry2D.segment_intersects_segment(from, to, line.points[idx], line.points[idx + 1]):
				to_delete.append(line)
				break
			idx += 1
	for line in to_delete:
		line.queue_free()


func _create_line(new_color : Color, new_width : float, points := PackedVector2Array()) -> Line2D:
	var line = Line2D.new()
	line.default_color = new_color
	line.width = new_width
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = points
	return line
