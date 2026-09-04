extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 60

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

var mana_cost: float = 10.0
@onready var hakubo = get_parent() as CharacterBody2D  # @onready 必須：ツリー投入後に get_parent() を評価

func spend_mana() -> bool:
	if hakubo and hakubo.has_node("ManaComponent"):
		var mana_component = hakubo.get_node("ManaComponent") as ManaComponent
		if mana_component:
			return mana_component.spend(mana_cost)
	return false

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_onagi":
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("parry") and can_parry and _try_consume_parry(area):
		var vp = get_viewport()
		var screen_pos = vp.get_canvas_transform() * area.global_position
		var uv = screen_pos / vp.get_visible_rect().size    # 0〜1 に正規化
		parried.emit(uv)
		can_parry = false
		attack_finished.emit()
		queue_free()
		return

	if area.is_in_group("player"):
		var player = area.get_parent() as CharacterBody2D
		if player.mana_component.has_method("take_damage"):
			player.mana_component.take_damage(damage)
			player.body_anim.play("damage")

var can_parry: bool = true

func change_can_parry_to(value: bool) -> void:
	can_parry = value

func _hakubo_slash() -> void:
	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		rotation = hakubo.direction
		hakubo.dash(0.5, distance_to_player * 6.0)
		hakubo.jump(25.0, 0.5)  # jump(height, duration): 25px を 0.5秒で。引数の順に注意

func do_paint() -> void:
	if paint_layer:
		paint_layer.paint_fan(get_parent().global_position, get_parent().direction, deg_to_rad(110), 30, 3)

		AudioManager.play_se("slash")
		AudioManager.play_se("ink_splash_small")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rotation = get_parent().direction
	animation_player.play("attack_onagi")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	var hakubo = get_parent() as CharacterBody2D
	if hakubo:
		var distance_to_player = hakubo.get_player_distance()
		hakubo.dash(0.5, distance_to_player * 2.5)

# パリィは「1回のパリィ入力につき1発」しか成立させない。
# パリィノードへ同期的に消費を申し出て、受理された場合のみ成立とする。
# 同期呼び出しなので、同一物理フレーム内のシグナル発火順に依存しない。
func _try_consume_parry(area: Area2D) -> bool:
	var parry_node = area.get_parent()
	if parry_node and parry_node.has_method("try_consume"):
		return parry_node.try_consume()
	return true
