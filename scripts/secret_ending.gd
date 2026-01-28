extends Area3D

# Dialogue configuration
@export var dialogue_canvas_path: NodePath
@export var next_scene: PackedScene

# First interaction: auto-chain dialogue (array or classic key)
@export_group("Auto-Chain Dialogue")
@export var auto_chain_start_id: String = "SecretZone"  # ← changed to array name if you renamed it

var first_interaction_done = false
var checkPlayer = false
var just_closed_dialogue: bool = false

var dialogue_canvas

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if dialogue_canvas_path:
		var canvas_layer = get_node(dialogue_canvas_path)
		if canvas_layer:
			dialogue_canvas = canvas_layer.get_node("ControlNode")  # or whatever your Control node is named
			if not dialogue_canvas:
				push_warning("Control node not found in DialogueCanvas!")
		else: push_warning("DialogueCanvas not found at path: " + str(dialogue_canvas_path))
	else: push_warning("DialogueCanvas path not assigned!")


func _on_body_entered(body):
	if body.is_in_group("player"):
		checkPlayer = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		checkPlayer = false


func _process(_delta):
	if just_closed_dialogue:
		just_closed_dialogue = false
		return

	if checkPlayer and Input.is_action_just_pressed("shoot"):
		interact()


func interact():
	if not dialogue_canvas:
		push_warning("DialogueCanvas reference not set!")
		return

	# Only auto-chain first interaction
	if not first_interaction_done and auto_chain_start_id != "":
		first_interaction_done = true
		dialogue_canvas.start_dialogue(auto_chain_start_id)
		dialogue_canvas.dialogue_finished.connect(_on_auto_chain_finished, CONNECT_ONE_SHOT)


func _on_auto_chain_finished():
	print("Auto-chain dialogue finished")
	just_closed_dialogue = true

	# Optionally change scene after first dialogue ends
	if next_scene:
		print("Changing scene...")
		get_tree().change_scene_to_packed(next_scene)
