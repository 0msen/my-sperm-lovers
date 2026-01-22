extends Area3D

# Dialogue configuration
@export var dialogue_canvas_path: NodePath
@export var next_scene: PackedScene

# First interaction: auto-chain dialogue
@export_group("Auto-Chain Dialogue")
@export var auto_chain_start_id: String = "SecretZone0" # First dialogue that auto chains

# Subsequent interactions: manual progression
@export_group("Manual Progression")
@export var manual_dialogue_ids: Array[String] = ["Doorethy0", "Doorethy1", "Doorethy2"]

var manual_index = 0                    # Track which manual dialogue to play next
var first_interaction_done = false      # Track if auto-chain has played
var checkPlayer = false
var just_closed_dialogue: bool = false
var dialogue_canvas

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Get the scene's ControlNode (it contains the script dialog_system.gd)
	if dialogue_canvas_path:
		var canvas_layer = get_node(dialogue_canvas_path)
		if canvas_layer:
			dialogue_canvas = canvas_layer.get_node("ControlNode")
			if not dialogue_canvas:
				push_warning("Control node not found in DialogueCanvas!")
		else:
			push_warning("DialogueCanvas not found at path: " + str(dialogue_canvas_path))
	else:
		push_warning("DialogueCanvas path not assigned!")

func _on_body_entered(body):
	if body.is_in_group("player"):
		checkPlayer = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		checkPlayer = false

func _process(_delta):
	# Skip input check for exactly one frame after dialogue just closed
	if just_closed_dialogue:
		just_closed_dialogue = false
		return

	if checkPlayer and Input.is_action_just_pressed("shoot"):
		interact()

func interact():
	if not dialogue_canvas:
		push_warning("DialogueCanvas reference not set!")
		return

	# First interaction: play auto-chaining dialogue
	if not first_interaction_done and auto_chain_start_id != "":
		first_interaction_done = true
		dialogue_canvas.start_dialogue(auto_chain_start_id, true) # auto_chain = true
		dialogue_canvas.dialogue_finished.connect(_on_auto_chain_finished, CONNECT_ONE_SHOT)
		return

	# Subsequent interactions: play manual dialogues one at a time
	if manual_index < manual_dialogue_ids.size():
		var dialogue_id = manual_dialogue_ids[manual_index]
		manual_index += 1
		dialogue_canvas.start_dialogue(dialogue_id, false) # auto_chain = false
		dialogue_canvas.dialogue_finished.connect(_on_manual_finished, CONNECT_ONE_SHOT)

func _on_auto_chain_finished():
	print("Auto-chain dialogue finished - player can move again")
	just_closed_dialogue = true

func _on_manual_finished():
	just_closed_dialogue = true
	# Check if this was the last manual dialogue
	if manual_index >= manual_dialogue_ids.size():
		print("Last dialogue finished - changing scene")
		if next_scene:
			get_tree().change_scene_to_packed(next_scene)
		else:
			print("No Scene Loaded yet")
	else:
		print("Manual dialogue finished - player can move again")
