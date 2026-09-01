class_name DropCategoryData
extends Resource


@export var category_name: String = "Drops"
## Only enemies whose data resource is listed here can roll this category.
@export var enemies: Array[Resource] = []
## Each roll independently chooses one weighted pickup or no drop.
@export_range(1, 100, 1, "or_greater") var rolls: int = 1
## Relative to the pickup weights; zero guarantees a pickup when the pool is valid.
@export_range(0.0, 1000.0, 0.01, "or_greater") var no_drop_weight: float = 0.0
@export var drops: Array[WeightedDropData] = []
