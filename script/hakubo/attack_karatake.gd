extends HakuboAttack

@export var exclamation_1 : Sprite2D
@export var exclamation_2 : Sprite2D
@export var exclamation_3 : Sprite2D

var target_position: Vector2 = Vector2.ZERO

func rotate_exclamation_marks() -> void:
	exclamation_1.global_rotation = 0.0
	exclamation_2.global_rotation = 0.0
	exclamation_3.global_rotation = 0.0

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_karatake":
		finish_attack()

func do_paint() -> void:
	if paint_layer:
		var from = get_parent().global_position
		var to = from + Vector2(cos(self.global_rotation), sin(self.global_rotation)) * 300
		paint_layer.paint_band(from, to, 40, 3)

		AudioManager.play_se("beam_shot")

func _ready() -> void:
	super()
	animation_player.play("attack_karatake")
	if animation_rig:
		animation_rig.play_attack_animation("attack_karatake", self, Vector2.from_angle(hakubo.direction))

	target_position = get_parent().get_player_position()

	AudioManager.play_se("beam_charge")

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle()

func _on_player_hit(player: Node) -> void:
	super(player)
	disable_hitbox()
