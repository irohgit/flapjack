class_name SkewerHarpoonEffect
extends AugmentEffect


func apply_to_projectile(projectile: Projectile) -> void:
	if projectile.skewer != null:
		return
	projectile.skewer = HarpoonSkewer.new()
	projectile.add_child(projectile.skewer)
