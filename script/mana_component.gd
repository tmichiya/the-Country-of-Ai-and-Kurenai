extends Node
class_name ManaComponent

signal mana_changed(current: float, max: float)
signal depleted

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var max_mana: float = 100.0
var mana: float

func reset() -> void:
	mana = max_mana
	mana_changed.emit(mana, max_mana)

func set_max_mana(value: float) -> void:
	max_mana = value
	
func get_mana() -> float:
	return mana

func get_max_mana() -> float:
	return max_mana

func get_mana_percentage() -> float:
	return mana / max_mana

func _ready() -> void:
	mana = max_mana

func take_damage(amount: float) -> void:
	AudioManager.play_se("damage")

	print("ManaComponent: Taking damage: ", amount)
	_change(-amount)
	animation_player.play("anim/damage")
	Effects.shake(2.0)

func can_spend(amount: float) -> bool:
	return mana >= amount 

func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	_change(-amount) 
	return true

func restore(amount: float) -> void:
	_change(amount)

func _change(delta_mana: float) -> void:
	# depleted は「0 になった “瞬間” 」だけ発火させる（エッジ検出）。
	# 以前は `if mana <= 0.0` だったので、0 のまま _change が呼ばれるたびに何度も飛んでいた。
	# 撃破回数を数える側からすると「1回の枯渇 = 1回のシグナル」でないと数がずれるため、
	# 数える側でガードするより、発信源であるここを正しくしておくほうが健全。
	var before := mana
	mana = clamp(mana + delta_mana, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)
	if before > 0.0 and mana <= 0.0:
		depleted.emit()