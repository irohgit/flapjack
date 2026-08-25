extends ParallaxProp
class_name VariantProp

func setup(prop_depth: float, camera: Node2D) -> void:
	# keep one random sprite variant, drop the rest, then run the normal setup
	var sprites: Array[Node] = []
	for child in get_children():
		if child is Sprite2D:
			sprites.append(child)
	if not sprites.is_empty():
		var keep: Node = sprites.pick_random()
		for s in sprites:
			if s != keep:
				s.queue_free()
	super.setup(prop_depth, camera)
