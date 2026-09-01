extends CanvasLayer

@onready var player_mana_bar: ColorRect = $CenterContainer/HUD/Player/PlayerManaBar
@onready var player_mana_bar_background: ColorRect = $CenterContainer/HUD/Player/PlayerBaseBar
@onready var hakubo_mana_bar: ColorRect = $CenterContainer/HUD/Boss/hakuboManaBar
@onready var hakubo_mana_bar_background: ColorRect = $CenterContainer/HUD/Boss/hakuboBaseBar

@onready var title_screen_anim: AnimationPlayer = $CenterContainer/TitleScreen/AnimationPlayer
@onready var title_screen_time_label: Label = $CenterContainer/TitleScreen/Control/Time/Label

var player_mana_bar_max_height: float
var hakubo_mana_bar_max_width: float

func set_player_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * player_mana_bar_max_height
	var tw = create_tween()
	tw.tween_property(player_mana_bar, "scale:x", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_hakubo_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * hakubo_mana_bar_max_width
	var tw = create_tween()
	tw.tween_property(hakubo_mana_bar, "scale:x", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_title_screen_time(time: String) -> void:
	title_screen_time_label.text = time

func show_title_screen() -> void:
	title_screen_anim.play("stage_title")

func _ready() -> void:
	player_mana_bar_max_height = player_mana_bar_background.scale.y
	hakubo_mana_bar_max_width = hakubo_mana_bar_background.scale.x
