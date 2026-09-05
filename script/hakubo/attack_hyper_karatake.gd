extends Node2D
signal attack_finished
signal parried(position: Vector2)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var damage: int = 20

var paint_layer: Node2D = null
var is_telegraphing: bool = false

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

func get_player_position() -> Vector2:
	if hakubo:
		return hakubo.get_player_position()
	return Vector2.ZERO

func _on_animation_finished(anim_name: String) -> void:
	# 再生されるのは "attack_hyper_karatake_1" 等（番号付き）なので、
	# 番号なしの完全一致だと永遠に一致せず attack_finished が出ない＝ATTACKで固まる。
	# begins_with で全バリエーションに一致させる。
	if anim_name.begins_with("attack_hyper_karatake"):
		attack_finished.emit()
		queue_free()

func _child_is_parried(uv: Vector2) -> void:
	print("child parried")
	parried.emit(uv)

@onready var karatake_child_scene = preload("res://scene/hakubo/attack_hyper_karatake_child.tscn")
func shot_karatake_child(angle: float) -> void:
	var karatake_child_instance = karatake_child_scene.instantiate() as Node2D
	var boss = get_parent()
	boss.add_child(karatake_child_instance)
	karatake_child_instance.global_rotation = global_rotation
	karatake_child_instance.rotation += deg_to_rad(angle)
	karatake_child_instance.angle_offset = angle
	karatake_child_instance.paint_layer = paint_layer
	karatake_child_instance.damage = damage

	# 子のヒットボックスが有効になるのは子アニメの 0.6〜0.7s。
	# 一方この攻撃ノード自身は自アニメ終了(0.7s)で queue_free() されるため、
	# パリィが起きる頃には既に解放済み＝この対象への接続は自動で切れてしまう。
	# よって親(hakubo)へ直接つなぐ。hakubo が居ない場合のみ従来の中継にフォールバック。
	if boss.has_method("parried"):
		karatake_child_instance.parried.connect(boss.parried.bind(true))
	else:
		karatake_child_instance.parried.connect(_child_is_parried)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# loop1 or loop2 で攻撃バリエーションの数を変える
	var max_attack_variation = 5
	var current_loop_count = GameManager.get_loop_count()
	if current_loop_count == 2:
		max_attack_variation = 5
	else:
		max_attack_variation = 3
	animation_player.play("attack_hyper_karatake_%d" % (randi() % max_attack_variation + 1))
	animation_player.animation_finished.connect(_on_animation_finished)

	target_position = get_player_position()

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle()
