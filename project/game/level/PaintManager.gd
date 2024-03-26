extends CanvasLayer

var default_color = Color(1.0,0.0,0.0)
var default_width = 10
var current_line
var active := false

func _input(event):
	if not active:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			start_new_line()
		else:
			stop_line()
	elif event is InputEventMouseMotion:
		increase_line()


func start_new_line():
	current_line = _create_line(default_color, default_width)
	%Lines.add_child(current_line)
	current_line.add_point(%Lines.get_local_mouse_position())


func stop_line():
	current_line = null


func increase_line():
	if not current_line:
		return
	current_line.add_point(%Lines.get_local_mouse_position())


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


func _create_line(new_color : Color, new_width : float, points := PackedVector2Array()) -> Line2D:
	var line = Line2D.new()
	line.default_color = new_color
	line.width = new_width
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = points
	return line
