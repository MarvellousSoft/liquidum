class_name SingleDayLeaderboard
extends ScrollContainer

@onready var Grid: GridContainer = %Grid
var cur_downloader: ImageDowloader = null

func _ready() -> void:
	clear_leaderboard()
	for c in ["Icon1", "Pos1", "NameContainer1", "Mistakes1", "Time1"]:
		Grid.get_node(c).hide()

func clear_leaderboard() -> void:
	# Leave the first five for copying so we don't need to programatically set stuff
	while Grid.get_child_count() > 10:
		var c := Grid.get_child(Grid.get_child_count() - 1)
		Grid.remove_child(c)
		c.queue_free()

class ImageDowloader extends Node:
	static var cache: Dictionary = {}
	var icons: Array[TextureRect] = []
	var urls: Array[String] = []
	var reqs: Array[HTTPRequest] = []
	var canceled := false
	func cancel() -> void:
		canceled = true
		for req in reqs:
			req.cancel_request()
	func add_image(icon: TextureRect, url: String) -> void:
		if ImageDowloader.cache.has(url):
			var img := Image.new()
			img.load_jpg_from_buffer(ImageDowloader.cache[url])
			icon.texture = ImageTexture.create_from_image(img)
			return
		icons.append(icon)
		urls.append(url)
		var req := HTTPRequest.new()
		reqs.append(req)
		add_child(req)
		req.request_completed.connect(_request_completed.bind(icons.size() - 1, req))
	func _download(i: int) -> void:
		if canceled:
			return
		var req: HTTPRequest = reqs[i]
		req.call_deferred("request", urls[i])
		await req.request_completed
	func _request_completed(result: int, _response_code: int, _headers, body: PackedByteArray, i: int, req: HTTPRequest) -> void:
		print("[%d] Finished downloading %s" % [i, urls[i]])
		remove_child(req)
		req.queue_free()
		if result != OK:
			return
		var img := Image.new()
		if img.load_jpg_from_buffer(body) == OK:
			ImageDowloader.cache[urls[i]] = body
			img.generate_mipmaps()
			icons[i].texture = ImageTexture.create_from_image(img)
		else:
			push_warning("Failed to download image from %s" % [urls[i]])
	func start_all_downloads() -> void:
		WorkerThreadPool.add_group_task(self._download, icons.size(), 5, false, "Downloads leaderboard icons")

func display_day(data: RecurringMarathon.LeaderboardData, date: String) -> void:
	clear_leaderboard()
	if cur_downloader != null:
		cur_downloader.canceled = true
		remove_child(cur_downloader)
	assert(is_inside_tree())
	cur_downloader = ImageDowloader.new()
	add_child(cur_downloader)
	Grid.get_node("Date").text = date
	for item in data.list:
		var icon := Grid.get_node("Icon1").duplicate()
		if item.image != null:
			icon.texture = ImageTexture.create_from_image(item.image)
		elif item.image_url != "":
			cur_downloader.add_image(icon, item.image_url)
		var pos := Grid.get_node("Pos1").duplicate()
		pos.text = "%d." % item.global_rank
		var name_ := Grid.get_node("NameContainer1").duplicate()
		name_.get_node("Name").text = item.text
		var flair: Label = name_.get_node("Flair")
		var sflair: SelectableFlair = FlairManager.create_flair(item.flair.id) if item.flair != null else null
		flair.visible = sflair != null
		if sflair != null:
			flair.tooltip_text = sflair.description
			flair.text = " %s " % [sflair.text]
			flair.add_theme_color_override("font_color", sflair.color)
			var contrast_color := Global.get_contrast_background(sflair.color)
			contrast_color.a = 0.75
			flair.get_node("BG").modulate = contrast_color
			var plus: Label = flair.get_node("Plus")
			plus.visible = item.flair.extra_flairs > 0
			plus.text = "+%d" % [item.flair.extra_flairs]
		var mistakes := Grid.get_node("Mistakes1").duplicate()
		mistakes.text = str(item.mistakes)
		var time := Grid.get_node("Time1").duplicate()
		time.text = Level.time_str(item.secs)
		for c in [icon, pos, name_, mistakes, time]:
			c.show()
			Grid.add_child(c)
	cur_downloader.start_all_downloads()
	update_theme(Profile.get_option("dark_mode"))

func update_theme(_dark_mode: bool) -> void:
	pass
