class_name AttackData
extends Resource

## 1つの攻撃の「定義」をまとめて持つデータ資産。
## 名前・コスト・生成シーン・AI評価パラメータ・スタンス相性を、この1か所に集約する。
##
## Resource を継承しているので、将来この定義を .tres ファイルとして保存すれば、
## Godot エディタのインスペクタ上でコストやシーンをドラッグ＆ドロップで編集できる。
## （＝データとコードの分離。実務でも敵・アイテム・スキルの管理に使う定番パターン）

## 内部ID。この攻撃を指す「唯一の名前」。ここだけが正となる。
@export var id: String = ""

## 生成する攻撃シーン。
@export var scene: PackedScene

## この攻撃を撃つのに必要なマナ。
@export var mana_cost: float = 0.0

# === AI の距離評価に使う基本パラメータ ===
## 適正距離の下限・上限。この範囲に近いほど高スコアになる。
@export var min_range: float = 0.0
@export var max_range: float = 200.0
## true なら「近いほど高評価」に反転する（懐に潜り込む技など）。
@export var range_inverted: bool = false
## 基本スコアの倍率（例: onagi の ×1.5）。
@export var base_multiplier: float = 1.0

## スタンス別の重み。キーは "OFFENSIVE" / "RETREAT" / "PAINT"。
## 未指定のスタンス（NEUTRAL 含む）は 1.0 として扱う。
@export var stance_affinity: Dictionary = {}

## dash 系かどうか。true の場合、生成後に現在スタンスへ応じて着地挙動を切り替える。
@export var is_dash: bool = false
