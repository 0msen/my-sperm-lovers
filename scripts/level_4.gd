extends Node3D

# abstract_door.gd will fetch this
signal puzzle_completed

@onready var organs = {
	"red": get_node("RedOrgan"),
	"blue": get_node("BlueOrgan"),
	"green": get_node("GreenOrgan"),
	"yellow": get_node("YellowOrgan")
}
@onready var fuse_box: StaticBody3D = $FuseBox
@onready var dialog_system: Control = $DialogSystem/ControlNode
@onready var BUZZER: AudioStreamPlayer = $Buzz
@onready var CORRECT: AudioStreamPlayer = $Correct
@onready var CHEER: AudioStreamPlayer = $Cheer
@onready var LAUGH: AudioStreamPlayer = $Laugh
@onready var trigger_zone: Area3D = $TriggerZone

var current_sequence = []
var player_sequence = []
var current_round = 0
var is_showing_sequence = false
var is_player_turn = false
var game_ended: bool = false  # True if door opened (by puzzle OR violence)
var game_has_started: bool = false   # ← prevents multiple triggers after player won

func _ready():
	# Initialize all organs to show normal, hide glow
	for organ_name in organs.keys():
		var organ = organs[organ_name]
		var normal_mesh = organ.get_node("Normal")
		var glow_mesh = organ.get_node("Glow")
		
		normal_mesh.visible = true
		glow_mesh.visible = false
	
	# Connect fuse box destruction signal
	if fuse_box:
		fuse_box.destroyed.connect(_on_fuse_box_destroyed)
		print("FuseBox Door now connected")
	
	if trigger_zone:
		trigger_zone.body_entered.connect(_on_trigger_zone_body_entered)
		print("Trigger zone connected")
	
	print("Simon Says initialized!")

func _on_trigger_zone_body_entered(body: Node3D) -> void:
	if game_ended: return
	if game_has_started: return 
		
	if body.is_in_group("player"):
		print("Player entered trigger zone → starting Simon Says")
		game_has_started = true
		start_game()


func glow_organ(color: String):
	var organ = organs[color]
	var normal_mesh = organ.get_node("Normal")
	var glow_mesh = organ.get_node("Glow")
	
	normal_mesh.visible = false
	glow_mesh.visible = true
	
	var tween = create_tween()
	tween.tween_property(organ, "scale", Vector3(1.15, 1.15, 1.15), 0.15)
	CORRECT.play()
func unglow_organ(color: String):
	var organ = organs[color]
	var normal_mesh = organ.get_node("Normal")
	var glow_mesh = organ.get_node("Glow")
	
	normal_mesh.visible = true
	glow_mesh.visible = false
	
	var tween = create_tween()
	tween.tween_property(organ, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

# Connect these functions to each Area3D's input_event signal
func _on_red_area_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("red")
func _on_blue_area_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("blue")
func _on_green_area_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("green")
func _on_yellow_area_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		check_input("yellow")

func start_game():
	current_round = 1
	current_sequence = []
	dialog_system.start_dialogue("DoorethyL4_Game0")
	await dialog_system.dialogue_finished
	next_round()

func next_round():
	is_player_turn = false
	player_sequence = []
	var colors = ["red", "blue", "green", "yellow"]
	current_sequence.append(colors[randi() % colors.size()])
	await get_tree().create_timer(1.5).timeout
	show_sequence()

func show_sequence():
	is_showing_sequence = true
	
	for color in current_sequence:
		glow_organ(color)
		await get_tree().create_timer(0.8).timeout
		unglow_organ(color)
		await get_tree().create_timer(0.4).timeout
	
	is_showing_sequence = false
	is_player_turn = true
	dialog_system.start_dialogue("DoorethyL4_Game1") # "Now YOUR TURNN~!"
	await dialog_system.dialogue_finished

func check_input(color: String):
	# Critical FIX: Don't process input if not in player turn, showing sequence, or game is over
	if not is_player_turn or is_showing_sequence or current_round > 10 or game_ended:
		print("Input ignored - not player's turn or game over")
		return
	print("Player selected: ", color)
	
	glow_organ(color)
	await get_tree().create_timer(0.3).timeout
	unglow_organ(color)
	
	player_sequence.append(color)
	# Safety FIX: Prevent out-of-bounds access, player can spam buzz
	var step = player_sequence.size() - 1
	if step >= current_sequence.size():
		print("Warning: Player clicked too many times!")
		return
		
	if color != current_sequence[step]:
		# Implies, player made a mistake, thus, Immediately stop accepting input
		is_player_turn = false  
		
		if current_round == 9:
			dialog_system.start_dialogue("DorrethyL4_game2")
			BUZZER.play()
			LAUGH.play()
			await dialog_system.dialogue_finished
		else:
			dialog_system.start_dialogue("DorrethyL4_game3")
			BUZZER.play()
			LAUGH.play()
			await dialog_system.dialogue_finished
			
		await get_tree().create_timer(2.0).timeout
		reset_game()
		return
	
	if player_sequence.size() == current_sequence.size():
		# Implies, player won, thus, no need to ask for user input
		is_player_turn = false
		
		# Reward patience with karma (+5 per round completed)
		if GameManager: GameManager.add_karma_xp(20.0)
		if current_round == 10:
			# load an conversation related: "Ugh... FINE. I suppose you ARE cultured. You may pass."
			dialog_system.start_dialogue("DorrethyL4_game4")
			CHEER.play()
			await dialog_system.dialogue_finished
			complete_puzzle()
		else:
			current_round += 1
			# SAGING loads a DICTIONARY of strings similar to: "Wow, look at you following rules. Good puppy."
			dialog_system.start_dialogue("DorrethyL4_game5")
			CHEER.play()
			await dialog_system.dialogue_finished
			await get_tree().create_timer(2.0).timeout
			next_round()

func reset_game():
	current_round = 1
	current_sequence = []
	player_sequence = []
	await get_tree().create_timer(1.0).timeout
	next_round()

# === VIOLENCE PATH: Fuse Box Destruction ===
func _on_fuse_box_destroyed() -> void:
	if game_ended: return
	# Stop the Simon Says game immediately
	is_player_turn = false
	is_showing_sequence = false
	
	await get_tree().create_timer(1.0).timeout
	dialog_system.start_dialogue("DorrethyL4_game6")
	await dialog_system.dialogue_finished
	
	# Complet puzzle
	complete_puzzle()

func complete_puzzle() -> void:
	if game_ended: return
	game_ended = true
	emit_signal("puzzle_completed")
	print("emitted puzzle is now complete (EXPECTED: door will react)")
