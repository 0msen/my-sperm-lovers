extends StaticBody3D

@export var auto_chain_dialog_id: String # Refer to JSON

@onready var dialog_system: Control = $DialogSystem/ControlNode
@onready var interact_area: Area3D = $InteractArea

var can_interact := false
var dialog_playing := false
var first_interaction_done := false
var just_closed_dialogue := false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	
	if dialog_system:
		dialog_system.dialogue_finished.connect(_on_dialog_finished)
	else:
		push_warning("DialogSystem / ControlNode not found!")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		can_interact = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		can_interact = false


func _input(event: InputEvent) -> void:
	if not can_interact or dialog_playing:
		return
	
	if just_closed_dialogue:
		just_closed_dialogue = false
		return
	
	if event.is_action_pressed("shoot"):
		get_viewport().set_input_as_handled()
		interact()

func interact() -> void:
	if not dialog_system:
		push_warning("No dialog system reference!")
		return
	
	if not first_interaction_done and auto_chain_dialog_id != "":
		first_interaction_done = true
		dialog_playing = true
		dialog_system.start_dialogue(auto_chain_dialog_id, true)
	else:
		# Optional: feedback if already triggered or no dialogue set
		print("Interaction already used or no auto-chain dialogue assigned")

func _on_dialog_finished() -> void:
	dialog_playing = false
	just_closed_dialogue = true
