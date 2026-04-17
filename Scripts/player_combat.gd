extends Area3D

@export var controller_path: NodePath = NodePath("..")
@export var damage_tick_cooldown: float = 0.25

var controller: ProtoController
var damage_tick_timer: float = 0.0

func _ready() -> void:
	controller = get_node_or_null(controller_path) as ProtoController
	monitoring = true


func _physics_process(delta: float) -> void:
	if controller == null:
		return

	damage_tick_timer = maxf(damage_tick_timer - delta, 0.0)
	if controller.current_health <= 0.0:
		return

	var total_damage := 0.0
	for body in get_overlapping_bodies():
		if body == null or body == controller:
			continue
		if not body.has_method("get_damage"):
			continue
		total_damage += float(body.get_damage())

	if total_damage <= 0.0:
		return

	if damage_tick_timer <= 0.0:
		controller.apply_damage(total_damage * damage_tick_cooldown)
		damage_tick_timer = damage_tick_cooldown
