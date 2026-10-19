extends Node
class_name ManaComponent

signal mana_changed(current: float, max: float, reason: Reason)
signal depleted
signal damaged

enum Reason {
	TAKE_DAMAGE,
	SPEND,
	REGENERATE,
	PARRY
}

@export var animation_player: AnimationPlayer

@export var max_mana: float = 100.0
var mana: float

func reset() -> void:
	mana = max_mana
	mana_changed.emit(mana, max_mana, Reason.REGENERATE)

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

func take_damage(amount: float, reason: Reason) -> void:
	AudioManager.play_se("damage")
	damaged.emit()

	print("ManaComponent: Taking damage: ", amount)

	print("ManaComponent: Taking damage: ", amount)
	_change(-amount, reason)
	animation_player.play("damage")
	Effects.shake(2.0)

func can_spend(amount: float) -> bool:
	return mana > amount 

func spend(amount: float, reason: Reason) -> bool:
	if not can_spend(amount):
		return false
	_change(-amount, reason)
	return true

func restore(amount: float, reason: Reason) -> void:
	_change(amount, reason)

func _change(delta_mana: float, reason: Reason) -> void:
	var before := mana
	mana = clamp(mana + delta_mana, 0.0, max_mana)
	mana_changed.emit(mana, max_mana, reason)
	if before > 0.0 and mana <= 0.0:
		depleted.emit()
