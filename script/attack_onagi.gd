extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 20

var paint_layer: Node2D = null
var is_telegraphing: bool = false

func enable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionPolygon2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

# 以下変更の可能性あり

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_onagi":
		print("Attack Onagi animation finished")
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player = area.get_parent() as CharacterBody2D
		if player.mana_component.has_method("take_damage"):
			player.mana_component.take_damage(damage)

	if area.is_in_group("parry"):
		var vp = get_viewport()
		var screen_pos = vp.get_canvas_transform() * area.global_position
		var uv = screen_pos / vp.get_visible_rect().size    # 0〜1 に正規化
		parried.emit(uv)
		attack_finished.emit()
		queue_free()
		return


func _akane_slash() -> void:
	var akane = get_parent() as CharacterBody2D
	if akane:
		var distance_to_player = akane.get_player_distance()
		rotation = akane.direction
		akane.dash(0.5, distance_to_player * 6.0)
		akane.jump(0.5, 25.0)

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 30, 3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rotation = get_parent().direction
	animation_player.play("attack_onagi")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	var akane = get_parent() as CharacterBody2D
	if akane:
		var distance_to_player = akane.get_player_distance()
		akane.dash(0.5, distance_to_player * 2.5)
