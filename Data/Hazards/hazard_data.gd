# =============================================================================
# HazardData
#
# Specification for one kind of static hazard. The hazard scene reads this on
# spawn and configures itself, so a new variant is a .tres file and no new code.
# =============================================================================

class_name HazardData
extends Resource

@export var contact_damage := 1 # Damage dealt to the player on contact.
@export var hitbox_radius := 40.0 # Hitbox is a circle for cheap overlap tests. Keep it inside the sprite silhouette so grazes read as misses.
@export var spin := 0.0 # Radians per second. Zero for things that should not spin, like seaweed.
@export var texture: Texture2D
@export var visual_scale := 1.0 # Sprite scale, so one texture can serve small and large variants.
