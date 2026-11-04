class_name TrainingDummy
extends CharacterBody2D
## 訓練用の標的。その場から動かず、プレイヤーの方を向いて attack_scene（既定は薙ぎ）を出す。
## 見た目は Visual の子を差し替えるだけで変えられる（このスクリプトは Visual の中身を知らない）。
##
## 攻撃シーン（attack_onagi.gd など）は親を「持ち主」として扱い、次のものを読む。
## hakubo と同じ名前でそろえてあるので、攻撃シーン側は書き換えずに使い回せる。
##   direction / dash() / get_player_distance() / parried() / ManaComponent

signal attack_started
signal attack_finished
signal attack_parried

@export var player: CharacterBody2D
@export var paint_layer: Node2D
@export var attack_scene: PackedScene = preload("res://scene/hakubo/attack_onagi.tscn")
## 攻撃シーンの既定値（薙ぎは 50）を訓練用に上書きする。
@export var attack_damage: float = 15.0
@export var attack_range: float = 110.0
@export var attack_interval: float = 1.4
@export var auto_attack: bool = false

@export_group("見た目")
@export var telegraph_color: Color = Color(1.0, 0.45, 0.5)
@export var hit_flash_color: Color = Color(1.8, 1.8, 1.8)
@export var hit_flash_seconds: float = 0.08

@export_group("説明表示")
@export_multiline var guide_text: String = ""
@export var guide_action: StringName = &""
@export var guide_height: float = 34.0

@onready var mana_component: ManaComponent = $ManaComponent
@onready var visual: Node2D = $Visual
@onready var guide: PanelContainer = $Guide
@onready var guide_label: Label = %GuideLabel
@onready var guide_prompt: InputPrompt = %GuidePrompt
@onready var guide_prompt_slot: Control = %GuidePromptSlot

var direction: float = PI * 0.5
var attack_instance: Node2D = null
## 生成した攻撃の総数。課題の判定に使う側が、開始時の値との差を見る。
var attack_count: int = 0

var _cooldown: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	mana_component.depleted.connect(mana_component.reset)
	set_guide(guide_text, guide_action)


# === 外から使う操作 ===

func set_attack_enabled(enabled: bool) -> void:
	auto_attack = enabled
	_cooldown = attack_interval * 0.5


func is_attacking() -> bool:
	return is_instance_valid(attack_instance)


func set_guide(text: String, action: StringName = &"") -> void:
	guide_text = text
	guide_action = action
	guide_label.text = text
	guide.visible = text != ""
	guide_prompt_slot.visible = action != &""
	if action != &"":
		guide_prompt.action = action
	_layout_guide.call_deferred()


# === 攻撃シーンから呼ばれる（持ち主としての約束） ===

func dash(_length: float, _strength: float, _dir: float = 0.0) -> void:
	pass


func get_player_distance() -> float:
	if player:
		return global_position.distance_to(player.global_position)
	return 0.0


func parried(_uv: Vector2, _from_projectile: bool = false) -> void:
	attack_parried.emit()


# === プレイヤーの斬りから呼ばれる ===

func play_damage_animation() -> void:
	_flash_left = hit_flash_seconds


# === 内部 ===

func _physics_process(delta: float) -> void:
	if player:
		direction = global_position.direction_to(player.global_position).angle()

	if not auto_attack or is_attacking():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if get_player_distance() <= attack_range:
		_start_attack()


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	visual.modulate = _current_tint()


## Visual の色を決めるのはここだけ（被弾フラッシュと予備動作の色が奪い合わないように）。
func _current_tint() -> Color:
	if _flash_left > 0.0:
		return hit_flash_color
	if _is_attack_telegraphing():
		return telegraph_color
	return Color.WHITE


func _is_attack_telegraphing() -> bool:
	return is_attacking() and attack_instance.has_method("is_playing_telegraph_animation") \
		and attack_instance.is_playing_telegraph_animation()


func _start_attack() -> void:
	var inst: Node2D = attack_scene.instantiate()
	attack_instance = inst
	inst.paint_layer = paint_layer
	inst.damage = attack_damage
	inst.mana_cost = 0.0
	inst.attack_finished.connect(_on_attack_finished.bind(inst))
	if inst.has_signal("parried"):
		inst.parried.connect(parried)
	add_child(inst)
	inst.global_position = global_position
	attack_count += 1
	attack_started.emit()


func _on_attack_finished(finished: Node2D) -> void:
	if attack_instance == finished:
		attack_instance = null
	_cooldown = attack_interval
	attack_finished.emit()


func _layout_guide() -> void:
	guide.reset_size()
	guide.position = Vector2(-guide.size.x * 0.5, -guide_height - guide.size.y)
