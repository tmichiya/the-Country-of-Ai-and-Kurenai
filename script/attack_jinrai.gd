extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 20
@export var exclamation_1 : Sprite2D

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

var akane = get_parent() as CharacterBody2D

func _akane_slash() -> void:
	if not akane:
		print("Akane is null in _akane_slash()")
		akane = get_parent() as CharacterBody2D
	if akane:
		var distance_to_player = akane.get_player_distance()
		akane.dash(0.5, distance_to_player * 8.0)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jinrai":
		print("Attack Jinrai animation finished")
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
		paint_layer.paint_fan(get_parent().global_position, get_parent().rotation, deg_to_rad(110), 60, 3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_jinrai")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	print("is_playing_telegraph_animation: %s" % is_playing_telegraph_animation())
	if exclamation_1:
		exclamation_1.global_rotation = 0.0
	if is_playing_telegraph_animation():
		if akane : akane.rotate_towards_player()		
	if not akane:
		print("Akane is null in _process()")
		akane = get_parent() as CharacterBody2D
