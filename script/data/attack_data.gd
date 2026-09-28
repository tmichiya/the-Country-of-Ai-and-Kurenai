class_name AttackData
extends Resource

@export var id: String = ""

## 生成する攻撃シーン。
@export var scene: PackedScene

## この攻撃を撃つのに必要なマナ。
@export var mana_cost: float = 0.0

@export var min_range: float = 0.0
@export var max_range: float = 200.0
@export var range_inverted: bool = false
@export var base_multiplier: float = 1.0

## スタンス別の重み。キーは "OFFENSIVE" / "RETREAT" / "PAINT"。
## 未指定のスタンス（NEUTRAL 含む）は 1.0 として扱う。
@export var stance_affinity: Dictionary = {}

## dash 系かどうか。true の場合、生成後に現在スタンスへ応じて着地挙動を切り替える。
@export var is_dash: bool = false
