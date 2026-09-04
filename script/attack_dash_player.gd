extends Node2D

@onready var hit_box: Area2D = $Hitbox
@export var damage: int = 10

var paint_layer: Node2D = null

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy"):
		return

	var enemy = area.get_parent() as CharacterBody2D

	if enemy.has_method("take_damage"):
		if enemy.has_method("is_telegraphing") and enemy.is_telegraphing():
			enemy.take_damage(damage * 2)
			return
		enemy.take_damage(damage)


func _ready() -> void:
	if not hit_box:
		return
	hit_box.area_entered.connect(_on_hitbox_area_entered)
