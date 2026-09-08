extends ParallaxProp
class_name VariantProp

## Keeps one random visual child and drops the rest, so a single scene can
## hold several art variants. Sprite2D and AnimatedSprite2D are siblings under
## Node2D, so both have to be named explicitly.
func setup(prop_depth: float, camera: Node2D) -> void:
	var variants: Array[Node] = []
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			variants.append(child)

	if not variants.is_empty():
		var keep: Node = variants.pick_random()
		for v in variants:
			if v != keep:
				# Detach immediately. queue_free only frees at end of frame,
				# so the discarded variants would still be children when
				# super.setup() runs and counts them.
				remove_child(v)
				v.queue_free()

		if keep is AnimatedSprite2D:
			(keep as AnimatedSprite2D).play()
	super.setup(prop_depth, camera)
