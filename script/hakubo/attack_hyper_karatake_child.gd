extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 40

var paint_layer: Node2D = null
var is_telegraphing: bool = false

var angle_offset: float = 0.0

func enable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

# 以下変更の可能性あり

var target_position: Vector2 = Vector2.ZERO
var can_parry: bool = true

func change_can_parry_to(value: bool) -> void:
	can_parry = value

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_hyper_karatake_child":
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("parry") and can_parry:
		print("parried")
		var vp = get_viewport()
		var screen_pos = vp.get_canvas_transform() * area.global_position
		var uv = screen_pos / vp.get_visible_rect().size    # 0〜1 に正規化
		parried.emit(uv)
		can_parry = false
		attack_finished.emit()
		queue_free()

	if area.is_in_group("player"):
		print("hit player")
		var player = area.get_parent() as CharacterBody2D
		if player.mana_component.has_method("take_damage"):
			player.mana_component.take_damage(damage)
		hit_box.get_node("CollisionShape2D").set_deferred("Disabled", true)

func shake_camera() -> void:
	Effects.shake(1.0)

func do_paint() -> void:
	if paint_layer:
		var from = get_parent().global_position
		var to = from + Vector2(cos(self.global_rotation), sin(self.global_rotation)) * 300
		paint_layer.paint_band(from, to, 30, 3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_hyper_karatake_child")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	target_position = get_parent().get_player_position()

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle() + deg_to_rad(angle_offset)