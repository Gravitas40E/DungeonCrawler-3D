extends CanvasLayer

const BAR_BG = preload("res://Assets/UI/PixelHUD/UI_StatusBar_Bg.png")
const FONT = preload("res://Assets/Fonts/UncialAntiqua-Regular.ttf")

@export var player_path : NodePath = NodePath("../ProtoController")

@onready var backdrop: ColorRect = $Backdrop
@onready var card: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubTitle
@onready var options_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Options

var player: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	player = get_node_or_null(player_path)
	apply_fonts()
	populate_options()
	show_selector()


func apply_fonts() -> void:
	title_label.add_theme_font_override("font", FONT)
	title_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_font_override("font", FONT)
	subtitle_label.add_theme_font_size_override("font_size", 14)


func populate_options() -> void:
	if player == null or not player.has_method("get_adventurer_options"):
		return

	for child in options_container.get_children():
		child.queue_free()

	for option in player.get_adventurer_options():
		options_container.add_child(build_option_button(option))


func build_option_button(option: Dictionary) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = BAR_BG
	button.texture_hover = BAR_BG
	button.texture_pressed = BAR_BG
	button.texture_disabled = BAR_BG
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = Vector2(420, 64)
	button.modulate = Color(1.0, 1.0, 1.0, 0.96)
	button.pressed.connect(_on_option_selected.bind(StringName(option["id"])))

	var title := Label.new()
	title.text = "%s (%s)" % [option["temp_name"], option["class_name"]]
	title.position = Vector2(112, 7)
	title.size = Vector2(248, 26)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(title)

	var subtitle := Label.new()
	subtitle.text = option["archetype"]
	subtitle.position = Vector2(112, 33)
	subtitle.size = Vector2(248, 18)
	subtitle.modulate = Color(0.88, 0.84, 0.78, 0.9)
	subtitle.add_theme_font_override("font", FONT)
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(subtitle)

	return button


func show_selector() -> void:
	visible = true
	get_tree().paused = true


func hide_selector() -> void:
	visible = false
	get_tree().paused = false


func _on_option_selected(adventurer_id: StringName) -> void:
	if player != null and player.has_method("select_adventurer"):
		player.select_adventurer(adventurer_id)
	hide_selector()
