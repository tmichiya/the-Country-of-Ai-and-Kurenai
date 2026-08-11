extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 10

var paint_layer: Node2D = null
var is_telegraphing: bool = false

func enable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", false)

func disable_hitbox() -> void:
	hit_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func is_playing_telegraph_animation() -> bool:
	return is_telegraphing

func switch_is_telegraphing_to(value: bool) -> void:
	is_telegraphing = value

# 以下変更の可能性あり


func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_karatake":
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player = area.get_parent() as CharacterBody2D
		if player.has_method("take_damage"):
			player.take_damage(damage)

	if area.is_in_group("parry"):
		var vp = get_viewport()
		var screen_pos = vp.get_canvas_transform() * area.global_position
		var uv = screen_pos / vp.get_visible_rect().size    # 0〜1 に正規化
		parried.emit(uv)
		queue_free()
		return
	
func do_paint() -> void:
	if paint_layer:
		var from = get_parent().global_position
		var to = from + Vector2(cos(get_parent().rotation), sin(get_parent().rotation)) * 300
		paint_layer.paint_band(from, to, 30, 3)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_karatake")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)
