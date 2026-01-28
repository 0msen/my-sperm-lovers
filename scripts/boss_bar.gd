extends CanvasLayer

@export var boss_group_name: String = "boss"
@onready var container: Control = $BossHPContainer
@onready var health_bar: ProgressBar = $BossHPContainer/BossHealthBar

var boss: Node = null


func _ready() -> void:
	health_bar.max_value = 100
	container.modulate.a = 0.0
	container.visible = false
	_find_boss()


func _process(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		_find_boss()
		return

	if boss.is_aggro and not boss.is_dead:
		health_bar.value = boss.health

		if not container.visible:
			container.visible = true
			var tween = create_tween()
			tween.tween_property(container, "modulate:a", 1.0, 0.4).from(0.0)

	else:
		if container.visible:
			var tween = create_tween()
			tween.tween_property(container, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func(): container.visible = false)


func _find_boss() -> void:
	var bosses = get_tree().get_nodes_in_group(boss_group_name)
	if not bosses.is_empty():
		boss = bosses[0]
		if "max_health" in boss:
			health_bar.max_value = boss.max_health
		print("Boss HP bar connected to: ", boss.name)
	else:
		boss = null
