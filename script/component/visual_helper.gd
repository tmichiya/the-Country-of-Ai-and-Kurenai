extends Node2D

@onready var visual : Node2D = $Visual
@onready var anim : AnimationPlayer = $AnimationPlayer
@onready var area : Area2D = $Area2D

func _ready() -> void:
	area.entered.connect(_on_area_entered)
	area.exited.connect(_on_area_exited)	

	visual.visible = false

func _on_area_entered() -> void:
	anim.play("fade_in_visual")

func _on_area_exited() -> void:
	anim.play("fade_out_visual")