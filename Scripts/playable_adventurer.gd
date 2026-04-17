extends Node3D

enum AnimationState {
	IDLE,
	WALK,
	SPRINT,
	JUMP,
}

const GENERAL_SOURCE := &"GeneralSource"
const MOVEMENT_SOURCE := &"MovementSource"

@export_group("Movement")
@export var idle_source_name: StringName = GENERAL_SOURCE
@export var idle_animation: StringName = &"Idle_A"
@export var walk_source_name: StringName = MOVEMENT_SOURCE
@export var walk_animation: StringName = &"Walking_A"
@export var sprint_source_name: StringName = MOVEMENT_SOURCE
@export var sprint_animation: StringName = &"Running_A"
@export var jump_source_name: StringName = MOVEMENT_SOURCE
@export var jump_start_animation: StringName = &"Jump_Start"
@export var jump_air_animation: StringName = &"Jump_Idle"

@export_group("Actions")
@export var primary_action_source_name: StringName = &"MeleeSource"
@export var primary_action_animation: StringName = &"Melee_1H_Attack_Slice_Diagonal"
@export var secondary_action_source_name: StringName = &"RangedSource"
@export var secondary_action_animation: StringName = &"Ranged_1H_Shoot"
@export var cast_action_source_name: StringName = GENERAL_SOURCE
@export var cast_action_animation: StringName = &"Use_Item"

@export_group("Reactions")
@export var hit_source_name: StringName = GENERAL_SOURCE
@export var hit_animation: StringName = &"Hit_A"
@export var death_source_name: StringName = GENERAL_SOURCE
@export var death_animation: StringName = &"Death_A"

@export_group("Equipment")
@export var item_scene_path: String = ""
@export var item_bone_name: StringName = &"hand.r"
@export var item_offset_position: Vector3 = Vector3.ZERO
@export var item_offset_rotation_degrees: Vector3 = Vector3.ZERO
@export var item_offset_scale: Vector3 = Vector3.ONE

var current_animation_state: int = -1
var current_source_name: StringName = &""
var current_clip_name: StringName = &""
var action_locked := false
var dead := false
var model_skeleton: Skeleton3D
var source_data: Dictionary = {}
var item_mount: Node3D
var item_instance: Node3D

@onready var base_model: Node3D = $BaseModel
@onready var animation_sources: Node3D = $AnimationSources

func _ready() -> void:
	model_skeleton = find_skeleton(base_model)
	cache_animation_sources()
	setup_item()
	configure_animation_sources()
	play_state(AnimationState.IDLE)


func _process(_delta: float) -> void:
	copy_active_pose_to_model()
	update_item_attachment()


func play_state(state: int, prefer_jump_start: bool = true) -> void:
	if dead or action_locked:
		return
	if current_animation_state == state:
		return

	match state:
		AnimationState.IDLE:
			play_named_clip(idle_source_name, idle_animation, state)
		AnimationState.WALK:
			play_named_clip(walk_source_name, walk_animation, state)
		AnimationState.SPRINT:
			play_named_clip(sprint_source_name, sprint_animation, state)
		AnimationState.JUMP:
			var jump_animation := jump_start_animation if prefer_jump_start else jump_air_animation
			if not source_has_clip(jump_source_name, jump_animation):
				jump_animation = jump_air_animation
			play_named_clip(jump_source_name, jump_animation, state)


func perform_primary_action() -> bool:
	return play_action_clip(primary_action_source_name, primary_action_animation)


func perform_secondary_action() -> bool:
	return play_action_clip(secondary_action_source_name, secondary_action_animation)


func perform_cast_action() -> bool:
	return play_action_clip(cast_action_source_name, cast_action_animation)


func play_hit_reaction() -> bool:
	if dead:
		return false
	return play_action_clip(hit_source_name, hit_animation, true)


func play_death() -> bool:
	if dead:
		return false
	dead = true
	return play_action_clip(death_source_name, death_animation, true)


func is_action_locked() -> bool:
	return action_locked


func is_dead() -> bool:
	return dead


func play_action_clip(source_name: StringName, clip_name: StringName, allow_interrupt: bool = false) -> bool:
	if dead and clip_name != death_animation:
		return false
	if action_locked and not allow_interrupt:
		return false
	if not play_named_clip(source_name, clip_name, current_animation_state):
		return false

	action_locked = clip_name != death_animation
	return true


func play_named_clip(source_name: StringName, clip_name: StringName, state: int) -> bool:
	var data: Dictionary = source_data.get(source_name, {})
	if data.is_empty():
		return false

	var player: AnimationPlayer = data.get("player") as AnimationPlayer
	if player == null or not player.has_animation(clip_name):
		return false

	stop_other_players(source_name)
	player.play(clip_name, 0.15)
	current_source_name = source_name
	current_clip_name = clip_name
	current_animation_state = state
	return true


func source_has_clip(source_name: StringName, clip_name: StringName) -> bool:
	var data: Dictionary = source_data.get(source_name, {})
	if data.is_empty():
		return false
	var player: AnimationPlayer = data.get("player") as AnimationPlayer
	return player != null and player.has_animation(clip_name)


func stop_other_players(active_source_name: StringName) -> void:
	for source_name in source_data.keys():
		if source_name == active_source_name:
			continue
		var data: Dictionary = source_data[source_name]
		var player: AnimationPlayer = data.get("player") as AnimationPlayer
		if player != null:
			player.stop()


func cache_animation_sources() -> void:
	source_data.clear()
	if animation_sources == null or model_skeleton == null:
		return

	for child in animation_sources.get_children():
		if not (child is Node3D):
			continue
		var source_root := child as Node3D
		var skeleton := find_skeleton(source_root)
		var player := find_animation_player(source_root)
		if skeleton == null or player == null:
			continue

		source_data[source_root.name] = {
			"skeleton": skeleton,
			"player": player,
			"bone_map": build_bone_map(skeleton, model_skeleton),
		}


func configure_animation_sources() -> void:
	set_loop_mode(idle_source_name, idle_animation, Animation.LOOP_LINEAR)
	set_loop_mode(walk_source_name, walk_animation, Animation.LOOP_LINEAR)
	set_loop_mode(sprint_source_name, sprint_animation, Animation.LOOP_LINEAR)

	for data in source_data.values():
		var player: AnimationPlayer = data.get("player") as AnimationPlayer
		if player != null and not player.animation_finished.is_connected(_on_animation_finished):
			player.animation_finished.connect(_on_animation_finished)


func set_loop_mode(source_name: StringName, animation_name: StringName, loop_mode: int) -> void:
	var data: Dictionary = source_data.get(source_name, {})
	if data.is_empty():
		return
	var player: AnimationPlayer = data.get("player") as AnimationPlayer
	if player == null or not player.has_animation(animation_name):
		return
	var animation := player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = loop_mode


func copy_active_pose_to_model() -> void:
	if model_skeleton == null:
		return

	var data: Dictionary = source_data.get(current_source_name, {})
	if data.is_empty():
		return

	var source_skeleton: Skeleton3D = data.get("skeleton") as Skeleton3D
	var bone_map: Array[int] = data["bone_map"]
	if source_skeleton == null or bone_map.is_empty():
		return

	for source_bone_idx in range(bone_map.size()):
		var target_bone_idx := bone_map[source_bone_idx]
		if target_bone_idx == -1:
			continue
		model_skeleton.set_bone_pose_position(target_bone_idx, source_skeleton.get_bone_pose_position(source_bone_idx))
		model_skeleton.set_bone_pose_rotation(target_bone_idx, source_skeleton.get_bone_pose_rotation(source_bone_idx))
		model_skeleton.set_bone_pose_scale(target_bone_idx, source_skeleton.get_bone_pose_scale(source_bone_idx))


func setup_item() -> void:
	item_mount = get_node_or_null("ItemMount") as Node3D
	if item_mount == null:
		item_mount = Node3D.new()
		item_mount.name = "ItemMount"
		add_child(item_mount)

	if item_scene_path.is_empty():
		return

	var scene := load(item_scene_path)
	if scene is PackedScene:
		item_instance = (scene as PackedScene).instantiate()
		if item_instance is CollisionObject3D:
			var collision_object := item_instance as CollisionObject3D
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
		item_mount.add_child(item_instance)


func update_item_attachment() -> void:
	if item_mount == null or item_instance == null or model_skeleton == null:
		return

	var bone_idx := model_skeleton.find_bone(item_bone_name)
	if bone_idx == -1:
		return

	var bone_transform := model_skeleton.get_bone_global_pose_no_override(bone_idx)
	var offset_rotation := Vector3(
		deg_to_rad(item_offset_rotation_degrees.x),
		deg_to_rad(item_offset_rotation_degrees.y),
		deg_to_rad(item_offset_rotation_degrees.z)
	)
	var offset_basis := Basis.from_euler(offset_rotation)
	var offset_transform := Transform3D(offset_basis, item_offset_position)
	offset_transform.basis = offset_transform.basis.scaled(item_offset_scale)
	item_mount.global_transform = bone_transform * offset_transform


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != current_clip_name:
		return
	if dead:
		action_locked = true
		return
	if action_locked:
		action_locked = false
		current_animation_state = -1


func build_bone_map(source_skeleton: Skeleton3D, target_skeleton: Skeleton3D) -> Array[int]:
	var mapping: Array[int] = []
	if source_skeleton == null or target_skeleton == null:
		return mapping
	for source_bone_idx in range(source_skeleton.get_bone_count()):
		mapping.append(target_skeleton.find_bone(source_skeleton.get_bone_name(source_bone_idx)))
	return mapping


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
