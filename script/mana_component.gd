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
	_change(-amount)
	animation_player.play("anim/damage")
	Effects.shake(2.0)

func can_spend(amount: float) -> bool:
	return mana >= amount 

func spend(amount: float) -> bool:
	print("ManaComponent: Attempting to spend ", amount, " mana. Current mana: ", mana)
	if not can_spend(amount):
		return false
	_change(-amount) 
	return true

func restore(amount: float) -> void:
	_change(amount)

func _change(delta_mana: float) -> void:
	mana = clamp(mana + delta_mana, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)
	if mana <= 0.0:
		depleted.emit()
		print("ManaComponent: Mana depleted, emitting 'depleted' signal.")
