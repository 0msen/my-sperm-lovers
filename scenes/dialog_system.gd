extends Control

@export var text_speed: float = 30.0
@export_file("*.json") var jsonsrc: String

@onready var name_label: RichTextLabel = $DialogBox/NameLabel
@onready var text_label: RichTextLabel = $DialogBox/TextLabel
@onready var typing_sound: AudioStreamPlayer = $ControlNode/DialogBox/typing_sound

var _last_visible_chars := 0
signal dialogue_started
signal dialogue_finished

var scene_script: Dictionary = {}
var current_entry: Dictionary = {}
var current_key: String = ""

@onready var game_manager = GameManager

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if jsonsrc:
		load_json(jsonsrc)

func load_json(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open " + path)
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("JSON error: " + json.get_error_message())
		return
	var data = json.data
	if not data is Dictionary:
		push_error("Root must be Dictionary")
		return
	scene_script = data

func start_dialogue(entry_point: String = "start", _auto_advance: bool = false) -> void:
	if not scene_script.has(entry_point):
		push_warning("No such block: " + entry_point)
		return
	
	var node = scene_script[entry_point]
	var selected = _pick_random_line(node)
	if selected.is_empty():
		push_warning("No valid karma-matching line in " + entry_point)
		return
	
	_show_line(selected, entry_point)
	show()
	set_process(true)
	get_tree().paused = true
	dialogue_started.emit()

func _pick_random_line(value) -> Dictionary:
	if value is Dictionary:
		if value.has("text"):
			if _karma_matches(value):
				return value.duplicate()
			else:
				return {}
		
		var valid_lines: Array[Dictionary] = []
		for key in value.keys():
			var child = value[key]
			if child is Dictionary and child.has("text") and _karma_matches(child):
				valid_lines.append(child.duplicate())
		
		if valid_lines.is_empty():
			for key in value.keys():
				var child = value[key]
				if child is Dictionary and child.has("text") and not child.has("karma"):
					valid_lines.append(child.duplicate())
		
		if valid_lines.is_empty():
			push_warning("No karma-matching line in group")
			return {}
		
		return valid_lines[randi() % valid_lines.size()]
	
	if value is Array:
		if value.is_empty():
			return {}
		
		var valid_indices: Array[int] = []
		for i in value.size():
			var line = value[i]
			if line is Dictionary and line.has("text") and _karma_matches(line):
				valid_indices.append(i)
		
		if valid_indices.is_empty():
			for i in value.size():
				var line = value[i]
				if line is Dictionary and line.has("text") and not line.has("karma"):
					valid_indices.append(i)
		
		if valid_indices.is_empty():
			push_warning("No karma-matching line in array")
			return {}
		
		# Start from the first valid index (instead of random)
		# This prevents skipping early lines unintentionally
		var start_idx = valid_indices[0]
		var first = value[start_idx].duplicate()
		first["__array__"] = value
		first["__index__"] = start_idx
		return first
	
	push_warning("Unsupported node type")
	return {}

func _show_line(line: Dictionary, from_key: String = "") -> void:
	current_entry = line.duplicate()
	current_key = from_key
	name_label.text = line.get("name", "")
	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	_last_visible_chars = 0
	set_process(true)

func _process(delta: float) -> void:
	if text_label.visible_characters >= text_label.get_total_character_count():
		set_process(false)
		return
	
	var total = text_label.get_total_character_count()
	var chars_per_sec = text_speed
	text_label.visible_characters += int(delta * chars_per_sec) + 1
	text_label.visible_characters = mini(text_label.visible_characters, total)
# play typing sound only if new characters appeared
	
	if text_label.visible_characters > _last_visible_chars:
		var char_index = text_label.visible_characters - 1
		var char := text_label.text[char_index]
		
		if char != " " and char != "\n":
			typing_sound.pitch_scale = randf_range(0.97, 1.03)
			typing_sound.play()
		
		_last_visible_chars = text_label.visible_characters
func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if not event.is_action_pressed("shoot"): return
	
	get_viewport().set_input_as_handled()
	
	if text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters = text_label.get_total_character_count()
		_last_visible_chars = text_label.visible_characters
		return
	
	var next_line = _get_next_line()
	if next_line.is_empty():
		_end()
		return
	
	_show_line(next_line)

func _get_next_line() -> Dictionary:
	# Array continuation with karma skip
	if current_entry.has("__array__") and current_entry.has("__index__"):
		var arr: Array = current_entry["__array__"]
		var current_idx: int = current_entry["__index__"]
		var next_idx = current_idx + 1
		
		# Find the next valid (karma-matching) line after current
		for i in range(next_idx, arr.size()):
			var candidate = arr[i]
			if candidate is Dictionary and candidate.has("text") and _karma_matches(candidate):
				var next_line = candidate.duplicate()
				next_line["__array__"] = arr
				next_line["__index__"] = i
				return next_line
		
		# No more valid lines -> end sequence
		return {}
	
	# Classic next field
	var next_id = current_entry.get("next", "")
	if next_id.is_empty():
		return {}
	
	return _resolve_next_line(next_id)

func _resolve_next_line(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	
	var parts = path.split(".", false, 1)
	
	if parts.size() == 1:
		if scene_script.has(path):
			var node = scene_script[path]
			return _pick_random_line(node)
	
	if parts.size() == 2:
		var group_name = parts[0]
		var key = parts[1]
		if scene_script.has(group_name):
			var group = scene_script[group_name]
			if group is Dictionary and group.has(key):
				var node = group[key]
				if node is Dictionary and node.has("text"):
					if _karma_matches(node):
						return node.duplicate()
					else:
						return {}
				else:
					return _pick_random_line(node)
	
	push_warning("Cannot resolve next: " + path)
	return {}

func _karma_matches(line: Dictionary) -> bool:
	if not line.has("karma"):
		return true
	
	if game_manager == null:
		push_warning("GameManager not found – allowing line")
		return true
	
	# get raw_karma of player and compare
	var karma_obj = line["karma"]
	var effective = game_manager.get_karma_level_DialogSystem()
	
	var min_ok = true
	var max_ok = true
	
	if karma_obj.has("min"):
		min_ok = effective >= karma_obj["min"]
	if karma_obj.has("max"):
		max_ok = effective <= karma_obj["max"]
	print("Karma check:", line.get("text", "?"), " | current:", effective, " → match:", min_ok and max_ok)
	return min_ok and max_ok

func _end() -> void:
	hide()
	set_process(false)
	current_entry.clear()
	current_key = ""
	get_tree().paused = false
	dialogue_finished.emit()

func complete_text() -> void:
	text_label.visible_characters = text_label.get_total_character_count()
