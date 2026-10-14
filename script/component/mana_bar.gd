extends Control

# ManaBarは、ManaComponentを持つキャラクターのマナ量を表示するためのUIコンポーネント
# このscriptを持つControlノードは、子として2つのColorRect"MainManaBar"と"TrailManaBar"を持つ必要がある

@onready var main_mana_bar: ColorRect = $MainManaBar
@onready var trail_mana_bar: ColorRect = $TrailManaBar

## ManaComponentを所持しており、Node2Dからmana_changed signalを発行するものを想定
@export var observing_target: Node2D

var max_mana: float = 100.0

func _ready() -> void:
	observing_target.mana_changed.connect(_on_mana_changed)

var target_mana_scale: float = -1.0
var main_tw: Tween
var trail_tw: Tween
func _on_mana_changed(mana: float, max_mana: float, reason: ManaComponent.Reason) -> void:
	print("ManaBar: Mana changed: ", mana, "/", max_mana, " Reason: ", reason)
	
	max_mana = max_mana
	target_mana_scale = (mana / max_mana)

	if main_tw != null and main_tw.is_running():
		main_tw.kill()
	if trail_tw != null and trail_tw.is_running():
		trail_tw.kill()
	
	main_tw = create_tween()
	main_tw.tween_property(main_mana_bar, "scale:x", target_mana_scale, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.5, true, false, true).timeout

	trail_tw = create_tween()
	trail_tw.tween_property(trail_mana_bar, "scale:x", target_mana_scale, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	pass
