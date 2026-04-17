extends CharacterBody3D

enum AnimationState {
	IDLE,
	RUN,
	JUMP,
}

@export var target_path : NodePath = NodePath("../../ProtoController")
@export var move_speed : float = 3.4
@export var acceleration : float = 8.0
@export var stop_distance : float = 1.6
@export var model_yaw_offset_degrees : float = 0.0
@export var damage : float = 8.0

var target: Node3D
var current_state := -1
var base_skeleton: Skeleton3D
var idle_skeleton: Skeleton3D
var run_skeleton: Skeleton3D
var jump_skeleton: Skeleton3D
var idle_animation_player: AnimationPlayer
var run_animation_player: AnimationPlayer
var jump_animation_player: AnimationPlayer

@onready var body_visual: Node3D = $BodyVisual
@onready var base_model: Node3D = $BodyVisual/BaseModel
@onready var animation_sources: Node3D = $AnimationSources
@onready var idle_source: Node3D = $AnimationSources/IdleSource
@onready var run_source: Node3D = $AnimationSources/RunSource
@onready var jump_source: Node3D = $AnimationSources/JumpSource

func _ready() -> void:
	add_to_group("zombie_enemies")
	target = get_node_or_null(target_path) as Node3D
	base_skeleton = find_skeleton(base_model)
	idle_skeleton = find_skeleton(idle_source)
	run_skeleton = find_skeleton(run_source)
	jump_skeleton = find_skeleton(jump_source)
	idle_animation_player = find_animation_player(idle_source)
	run_animation_player = find_animation_player(run_source)
	jump_animation_player = find_animation_player(jump_source)
	configure_animation_player(idle_animation_player, &"Idle", Animation.LOOP_LINEAR)
	configure_animation_player(run_animation_player, &"Run", Animation.LOOP_LINEAR)
	configure_animation_player(jump_animation_player, &"jump", Animation.LOOP_NONE)
	animation_sources.visible = false
	set_animation_state(AnimationState.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var desired_velocity := Vector3.ZERO
	if target != null:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > stop_distance:
			var direction := to_target / distance
			desired_velocity = direction * move_speed
			var target_yaw := atan2(direction.x, direction.z) + deg_to_rad(model_yaw_offset_degrees)
			body_visual.rotation.y = lerp_angle(body_visual.rotation.y, target_yaw, 10.0 * delta)

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	move_and_slide()
	update_animation_state()


func _process(_delta: float) -> void:
	copy_active_pose_to_base()


func get_damage() -> float:
	return damage


func update_animation_state() -> void:
	if not is_on_floor():
		set_animation_state(AnimationState.JUMP)
		return

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > 0.15:
		set_animation_state(AnimationState.RUN)
	else:
		set_animation_state(AnimationState.IDLE)


func set_animation_state(new_state : AnimationState) -> void:
	if current_state == new_state:
		return
	current_state = new_state

	match new_state:
		AnimationState.IDLE:
			play_animation(idle_animation_player, &"Idle")
			stop_animation(run_animation_player)
			stop_animation(jump_animation_player)
		AnimationState.RUN:
			play_animation(run_animation_player, &"Run")
			stop_animation(idle_animation_player)
			stop_animation(jump_animation_player)
		AnimationState.JUMP:
			play_animation(jump_animation_player, &"jump")
			stop_animation(idle_animation_player)
			stop_animation(run_animation_player)


func configure_animation_player(animation_player: AnimationPlayer, animation_name : StringName, loop_mode : int) -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(animation_name):
		var animation := animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = loop_mode


func play_animation(animation_player: AnimationPlayer, animation_name : StringName) -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)


func stop_animation(animation_player: AnimationPlayer) -> void:
	if animation_player == null:
		return
	animation_player.stop()


func copy_active_pose_to_base() -> void:
	if base_skeleton == null:
		return

	var source_skeleton := get_active_source_skeleton()
	if source_skeleton == null:
		return

	var bone_count := mini(base_skeleton.get_bone_count(), source_skeleton.get_bone_count())
	for bone_idx in range(bone_count):
		base_skeleton.set_bone_pose_position(bone_idx, source_skeleton.get_bone_pose_position(bone_idx))
		base_skeleton.set_bone_pose_rotation(bone_idx, source_skeleton.get_bone_pose_rotation(bone_idx))
		base_skeleton.set_bone_pose_scale(bone_idx, source_skeleton.get_bone_pose_scale(bone_idx))


func get_active_source_skeleton() -> Skeleton3D:
	match current_state:
		AnimationState.IDLE:
			return idle_skeleton
		AnimationState.RUN:
			return run_skeleton
		AnimationState.JUMP:
			return jump_skeleton
	return idle_skeleton


func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null


func find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null
