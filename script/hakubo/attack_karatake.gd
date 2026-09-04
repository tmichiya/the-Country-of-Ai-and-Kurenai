extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox
@export var damage: int = 20

@export var exclamation_1 : Sprite2D
@export var exclamation_2 : Sprite2D
@export var exclamation_3 : Sprite2D

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
# @onready を付けることで、ノードがツリーに入った後（_ready 直前）に初期化される。
# 付けないと instantiate 直後（まだ親が無い）に評価され get_parent() が null になり、
# spend_mana() の hakubo 参照が常に null＝マナ消費されない、というバグになる。
@onready var hakubo = get_parent() as CharacterBody2D

func spend_mana() -> bool:
	if hakubo and hakubo.has_node("ManaComponent"):
		var mana_component = hakubo.get_node("ManaComponent") as ManaComponent
		if mana_component:
			return mana_component.spend(mana_cost)
	return false

var target_position: Vector2 = Vector2.ZERO
var can_parry: bool = true

func change_can_parry_to(value: bool) -> void:
	can_parry = value

func rotate_exclamation_marks() -> void:
	exclamation_1.global_rotation = 0.0
	exclamation_2.global_rotation = 0.0
	exclamation_3.global_rotation = 0.0

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_karatake":
		attack_finished.emit()
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("parry") and can_parry and _try_consume_parry(area):
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
			player.body_anim.play("damage")
		hit_box.get_node("CollisionShape2D").set_deferred("Disabled", true)

func do_paint() -> void:
	if paint_layer:
		var from = get_parent().global_position
		var to = from + Vector2(cos(self.global_rotation), sin(self.global_rotation)) * 300
		paint_layer.paint_band(from, to, 30, 3)

		AudioManager.play_se("beam_shot")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("attack_karatake")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	target_position = get_parent().get_player_position()

	AudioManager.play_se("beam_charge")

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle()

# パリィは「1回のパリィ入力につき1発」しか成立させない。
# パリィノードへ同期的に消費を申し出て、受理された場合のみ成立とする。
# 同期呼び出しなので、同一物理フレーム内のシグナル発火順に依存しない。
func _try_consume_parry(area: Area2D) -> bool:
	var parry_node = area.get_parent()
	if parry_node and parry_node.has_method("try_consume"):
		return parry_node.try_consume()
	return true
