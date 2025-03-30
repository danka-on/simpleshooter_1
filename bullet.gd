extends Area3D

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : PackedScene = preload("res://hit_effect.tscn")

func _ready():
	collision_layer = 3 # Bullets
	collision_mask = 2 # Hits enemies

func _physics_process(delta):
	global_transform.origin += velocity * delta

func _on_area_entered(area):
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(10.0)
		var hit_effect = hit_effect_scene.instantiate()
		hit_effect.global_transform.origin = global_transform.origin # Hit position
		get_parent().add_child(hit_effect)
	queue_free()

func _on_lifetime_timeout():
	queue_free()
