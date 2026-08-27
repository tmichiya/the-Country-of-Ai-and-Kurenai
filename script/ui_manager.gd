extends CanvasLayer

@onready var player_mana_bar: ColorRect = $CenterContainer/HUD/PlayerManaBar
@onready var player_mana_bar_background: ColorRect = $CenterContainer/HUD/PlayerManaBarBackground
@onready var akane_mana_bar: ColorRect = $CenterContainer/HUD/AkaneManaBar
@onready var akane_mana_bar_background: ColorRect = $CenterContainer/HUD/AkaneManaBarBackground

var player_mana_bar_max_height: float
var akane_mana_bar_max_width: float

func set_player_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * player_mana_bar_max_height
	var tw = create_tween()
	tw.tween_property(player_mana_bar, "scale:y", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_akane_mana(mana: float, max_mana: float) -> void:
	var target = (mana / max_mana) * akane_mana_bar_max_width
	var tw = create_tween()
	tw.tween_property(akane_mana_bar, "scale:x", target, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	player_mana_bar_max_height = player_mana_bar_background.scale.y
	akane_mana_bar_max_width = akane_mana_bar_background.scale.x
