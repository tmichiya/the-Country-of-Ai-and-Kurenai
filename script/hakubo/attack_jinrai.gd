extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 50

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

var hakubo = get_parent() as CharacterBody2D

func _hakubo_slash() -> void:
	if not hakubo:
		hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		var player_vector = hakubo.get_player_vector()
		var expected_direction = ((hakubo.get_player_position() + player_vector * 60) - hakubo.global_position).normalized().angle()
		hakubo.set_direction(expected_direction)
		hakubo.set_direction(expected_direction)
		rotation = expected_direction
		hakubo.dash(0.5, distance_to_player * 9.0)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jinrai":
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

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 60, 3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hakubo = get_parent() as CharacterBody2D

	animation_player.play("attack_jinrai")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if is_playing_telegraph_animation():
		if hakubo :
			rotation = hakubo.direction			
