extends CanvasLayer

@export var player_path : NodePath = NodePath("../ProtoController")

@onready var health_bar: TextureProgressBar = $MarginContainer/VBoxContainer/HealthRow/BarStack/HealthBar
@onready var health_value: Label = $MarginContainer/VBoxContainer/HealthRow/BarStack/HealthValue
@onready var magicka_bar: TextureProgressBar = $MarginContainer/VBoxContainer/MagickaRow/BarStack/MagickaBar
@onready var magicka_value: Label = $MarginContainer/VBoxContainer/MagickaRow/BarStack/MagickaValue

func _ready() -> void:
	var player = get_node_or_null(player_path)
	if player != null and player.has_signal("stats_changed"):
		player.stats_changed.connect(_on_stats_changed)
		_on_stats_changed(player.current_health, player.max_health, player.current_magicka, player.max_magicka)


func _on_stats_changed(current_health: float, max_health: float, current_magicka: float, max_magicka: float) -> void:
	var health_ratio: float = 0.0
	if max_health > 0.0:
		health_ratio = clampf(current_health / max_health, 0.0, 1.0)

	var magicka_ratio: float = 0.0
	if max_magicka > 0.0:
		magicka_ratio = clampf(current_magicka / max_magicka, 0.0, 1.0)

	health_bar.max_value = max_health
	health_bar.value = health_ratio * max_health
	magicka_bar.max_value = max_magicka
	magicka_bar.value = magicka_ratio * max_magicka
	health_value.text = "%d / %d" % [roundi(current_health), roundi(max_health)]
	magicka_value.text = "%d / %d" % [roundi(current_magicka), roundi(max_magicka)]
