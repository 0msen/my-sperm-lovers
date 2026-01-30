extends Area3D
@export var next_scene: PackedScene
@export var good_scene: PackedScene
@export var bad_scene: PackedScene

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("player"):
		var raw_karma = GameManager.get_karma_level_DialogSystem()
		
		var target_scene: PackedScene
		if raw_karma <= -0.1:
			target_scene = bad_scene
			print("[LevelTrigger] Low karma (-0.1 or worse): Loading bad scene")
		elif raw_karma >= 0.1:
			target_scene = good_scene
			print("[LevelTrigger] High karma (0.1 or better): Loading good scene")
		else:
			target_scene = next_scene
			print("[LevelTrigger] Neutral karma: Loading default scene")
		
		if target_scene: get_tree().change_scene_to_packed(target_scene)
		else: print("No valid scene set for karma level! Raw karma: ", raw_karma)
