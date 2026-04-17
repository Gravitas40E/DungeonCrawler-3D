extends CharacterBody3D
class_name ProtoController

signal stats_changed(current_health: float, max_health: float, current_magicka: float, max_magicka: float)
signal adventurer_changed(adventurer_id: StringName)

const ADVENTURERS := [
	{
		"id": "barbarian",
		"class_name": "Barbarian",
		"temp_name": "Ashbreaker",
		"archetype": "Frontline bruiser",
		"scene_path": "res://Scenes/Playable/Barbarian.tscn",
	},
	{
		"id": "knight",
		"class_name": "Knight",
		"temp_name": "Iron Warden",
		"archetype": "Armored guardian",
		"scene_path": "res://Scenes/Playable/Knight.tscn",
	},
	{
		"id": "mage",
		"class_name": "Mage",
		"temp_name": "Starfire Adept",
		"archetype": "Arcane caster",
		"scene_path": "res://Scenes/Playable/Mage.tscn",
	},
	{
		"id": "ranger",
		"class_name": "Ranger",
		"temp_name": "Mossarrow",
		"archetype": "Swift pathfinder",
		"scene_path": "res://Scenes/Playable/Ranger.tscn",
	},
	{
		"id": "rogue",
		"class_name": "Rogue",
		"temp_name": "Quickshade",
		"archetype": "Agile duelist",
		"scene_path": "res://Scenes/Playable/Rogue.tscn",
	},
	{
		"id": "rogue_hooded",
		"class_name": "Rogue Hooded",
		"temp_name": "Veilstep",
		"archetype": "Hidden infiltrator",
		"scene_path": "res://Scenes/Playable/Rogue_Hooded.tscn",
	},
]

enum AnimationState {
	IDLE,
	WALK,
	SPRINT,
	JUMP,
}

@export var can_move : bool = true
@export var has_gravity : bool = true
@export var can_jump : bool = true
@export var can_sprint : bool = false
@export var can_freefly : bool = false

@export_group("Speeds")
@export var look_speed : float = 0.002
@export var base_speed : float = 7.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0
@export var freefly_speed : float = 25.0

@export_group("Third Person Camera")
@export var camera_distance : float = 4.5
@export var camera_height : float = 1.7
@export var min_pitch_degrees : float = -45.0
@export var max_pitch_degrees : float = 15.0

@export_group("Animation")
@export var model_yaw_offset_degrees : float = 0.0
@export var idle_animation : StringName = &"Idle_A"
@export var walk_animation : StringName = &"Walking_A"
@export var sprint_animation : StringName = &"Running_A"
@export var jump_start_animation : StringName = &"Jump_Start"
@export var jump_air_animation : StringName = &"Jump_Idle"

@export_group("Stats")
@export var max_health : float = 100.0
@export var max_magicka : float = 100.0

@export_group("Character")
@export var selected_adventurer_id : StringName = &"knight"

@export_group("Input Actions")
@export var input_left : String = "ui_left"
@export var input_right : String = "ui_right"
@export var input_forward : String = "ui_up"
@export var input_back : String = "ui_down"
@export var input_jump : String = "ui_accept"
@export var input_sprint : String = "sprint"
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_yaw : float = 0.0
var look_pitch : float = 0.0
var move_speed : float = 0.0
var freeflying : bool = false
var current_health : float = 0.0
var current_magicka : float = 0.0
var active_model: Node3D

@onready var body_visual: Node3D = $BodyVisual
@onready var model_mount: Node3D = $BodyVisual/ModelMount
@onready var collider: CollisionShape3D = $Collider
@onready var camera_yaw_pivot: Node3D = $CameraYawPivot
@onready var camera_pitch_pivot: Node3D = $CameraYawPivot/CameraPitchPivot
@onready var spring_arm: SpringArm3D = $CameraYawPivot/CameraPitchPivot/SpringArm3D

func _ready() -> void:
	check_input_mappings()
	current_health = max_health
	current_magicka = max_magicka
	camera_yaw_pivot.position.y = camera_height
	spring_arm.spring_length = camera_distance
	look_yaw = rotation.y
	look_pitch = camera_pitch_pivot.rotation.x
	apply_look_rotation()
	select_adventurer(selected_adventurer_id)
	emit_stats_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()

	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()


func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		var freefly_input := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (spring_arm.global_basis * Vector3(freefly_input.x, 0, -freefly_input.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return

	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	if can_jump and Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var has_move_input := input_dir.length() > 0.01
	var wants_to_sprint := can_sprint and Input.is_action_pressed(input_sprint) and has_move_input
	move_speed = sprint_speed if wants_to_sprint else base_speed

	if can_move:
		var camera_basis := spring_arm.global_basis
		var forward := -camera_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := camera_basis.x
		right.y = 0
		right = right.normalized()
		var move_dir := (right * input_dir.x + forward * -input_dir.y).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
			var target_yaw := atan2(move_dir.x, move_dir.z) + deg_to_rad(model_yaw_offset_degrees)
			body_visual.rotation.y = lerp_angle(body_visual.rotation.y, target_yaw, 12.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0

	move_and_slide()
	update_animation_state()
	emit_stats_changed()


func rotate_look(rot_input : Vector2) -> void:
	look_yaw -= rot_input.x * look_speed
	look_pitch -= rot_input.y * look_speed
	look_pitch = clamp(
		look_pitch,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	apply_look_rotation()


func apply_look_rotation() -> void:
	camera_yaw_pivot.rotation = Vector3(0.0, look_yaw, 0.0)
	camera_pitch_pivot.rotation = Vector3(look_pitch, 0.0, 0.0)


func update_animation_state() -> void:
	if active_model == null:
		return
	if active_model.has_method("is_action_locked") and active_model.is_action_locked():
		return
	if active_model.has_method("is_dead") and active_model.is_dead():
		return

	if not is_on_floor():
		if active_model.has_method("play_state"):
			active_model.play_state(AnimationState.JUMP, velocity.y > 0.1)
		return

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed < 0.1:
		if active_model.has_method("play_state"):
			active_model.play_state(AnimationState.IDLE)
	elif can_sprint and Input.is_action_pressed(input_sprint):
		if active_model.has_method("play_state"):
			active_model.play_state(AnimationState.SPRINT)
	else:
		if active_model.has_method("play_state"):
			active_model.play_state(AnimationState.WALK)


func get_adventurer_options() -> Array:
	return ADVENTURERS.duplicate(true)


func select_adventurer(adventurer_id: StringName) -> void:
	var data := get_adventurer_by_id(adventurer_id)
	if data.is_empty():
		data = ADVENTURERS[0]
	selected_adventurer_id = StringName(data["id"])

	if active_model != null:
		active_model.queue_free()
		active_model = null

	var scene := load(data["scene_path"])
	if scene is PackedScene:
		active_model = (scene as PackedScene).instantiate()
		model_mount.add_child(active_model)
		body_visual.rotation.y = 0.0
		adventurer_changed.emit(selected_adventurer_id)


func get_selected_adventurer() -> Dictionary:
	return get_adventurer_by_id(selected_adventurer_id)


func get_adventurer_by_id(adventurer_id: StringName) -> Dictionary:
	for option in ADVENTURERS:
		if option["id"] == String(adventurer_id):
			return option
	return {}


func emit_stats_changed() -> void:
	stats_changed.emit(current_health, max_health, current_magicka, max_magicka)


func apply_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	current_health = clampf(current_health - amount, 0.0, max_health)
	if active_model != null:
		if current_health > 0.0 and active_model.has_method("play_hit_reaction"):
			active_model.play_hit_reaction()
		elif current_health <= 0.0 and active_model.has_method("play_death"):
			active_model.play_death()
	emit_stats_changed()


func enable_freefly() -> void:
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO


func disable_freefly() -> void:
	collider.disabled = false
	freeflying = false


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func check_input_mappings() -> void:
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
