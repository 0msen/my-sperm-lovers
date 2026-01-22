extends Control

@export var text_speed: float = 30.0
@export_file("*.json") var jsonsrc: String

@onready var name_label: RichTextLabel = $DialogBox/NameLabel
@onready var text_label: RichTextLabel = $DialogBox/TextLabel

signal dialogue_finished
signal dialogue_started

var scene_script: Dictionary = {}
var current_block: Dictionary = {}
var current_block_id: String = ""
var char_timer: float = 0.0
var auto_advance: bool = false
var is_typing: bool = false

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	
	if jsonsrc:
		load_json(jsonsrc)

func load_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open dialogue file: " + path)
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		push_error("Failed to parse JSON: " + path)
		return
	
	scene_script = parsed

func start_dialogue(block_id: String = "start", auto_chain: bool = false) -> void:
	if not scene_script.has(block_id):
		push_warning("Dialogue block not found: " + block_id)
		return
	
	auto_advance = auto_chain
	current_block_id = block_id
	current_block = scene_script[block_id]
	
	load_block(current_block)
	show()
	set_process(true)
	get_tree().paused = true
	dialogue_started.emit()

func load_block(block: Dictionary) -> void:
	name_label.text = block.get("name", "")
	text_label.text = block.get("text", "")
	text_label.visible_characters = 0
	
	is_typing = true
	char_timer = 0.0

func _process(delta: float) -> void:
	if not is_typing:
		return
	
	var total_chars := text_label.get_total_character_count()
	
	if text_label.visible_characters < total_chars:
		char_timer += delta * text_speed
		
		var chars_to_add := int(char_timer)
		if chars_to_add > 0:
			text_label.visible_characters = mini(
				text_label.visible_characters + chars_to_add,
				total_chars
			)
			char_timer -= chars_to_add
	else:
		is_typing = false
		set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		if is_typing:
			complete_text()
		else:
			advance()

func complete_text() -> void:
	text_label.visible_characters = text_label.get_total_character_count()
	is_typing = false
	set_process(false)

func advance() -> void:
	var next_id = current_block.get("next", "")
	
	if next_id and auto_advance:
		if not scene_script.has(next_id):
			push_warning("Next block not found: " + next_id)
			end_dialogue()
			return
		current_block_id = next_id
		current_block = scene_script[next_id]
		load_block(current_block)
		set_process(true)
	else:
		end_dialogue()

func end_dialogue() -> void:
	hide()
	set_process(false)
	current_block.clear()
	current_block_id = ""
	auto_advance = false
	
	get_tree().paused = false
	dialogue_finished.emit()
