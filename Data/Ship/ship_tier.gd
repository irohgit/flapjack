# =============================================================================
# ShipTierData
#
# Visual definition for one hull tier. Damage textures run from healthiest to
# most damaged; the count is flexible, since the player maps health proportion
# onto the array length rather than using fixed thresholds.
# =============================================================================

class_name ShipTierData
extends Resource

@export var tier_name := "Skiff"
@export var hull_textures: Array[Texture2D] = []
@export_range(1, 8, 1) var display_scale := 5
@export var hitbox_radius := 10.0
@export var pickup_radius := 80.0
