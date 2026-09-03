extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 20

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

var mana_cost: float = 10.0
@onready var hakubo = get_parent() as CharacterBody2D  # @onready 必須：ツリー投入後に get_parent() を評価

func spend_mana() -> bool:
	if hakubo and hakubo.has_node("ManaComponent"):
		var mana_component = hakubo.get_node("ManaComponent") as ManaComponent
		if mana_component:
			return mana_component.spend(mana_cost)
	return false

@export var radius : float = 95.0

var can_parry: bool = true

func change_can_parry_to(value: bool) -> void:
	can_parry = value

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_jisome":
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
		var player = area.get_parent() as CharacterBody2D
		if player.mana_component.has_method("take_damage"):
			player.mana_component.take_damage(damage)
	
func do_paint() -> void:
	if paint_layer:
		var world_pos = get_parent().global_position
		paint_layer.paint_blob(world_pos, radius, 3, Vector2.ZERO)
		for i in range(15):
			var new_radius = radius * randf_range(0.1, 0.3)
			var offset = Vector2.from_angle(rad_to_deg(randf() * 360)) * radius * randf_range(1.0, 1.5)
			paint_layer.paint_blob(world_pos + offset, new_radius, 3, Vector2.ZERO)
			await get_tree().create_timer(randf_range(0.03, 0.05), true, false, true).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_jisome")
	animation_player.animation_finished.connect(_on_animation_finished)
	global_rotation = 0.0

	hit_box.area_entered.connect(_on_hitbox_area_entered)
