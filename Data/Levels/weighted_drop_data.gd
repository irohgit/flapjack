class_name WeightedDropData
extends Resource


@export var pickup: PickupData
## Relative to the other entries and the category's no-drop weight.
@export_range(0.0, 1000.0, 0.01, "or_greater") var weight: float = 1.0
