class_name UpgradeNodeData
extends Resource

enum StatType { RIGGING, ARMAMENT, HULL }

@export var id: StringName            # unique key, e.g. "rigging_1"
@export var display_name: String      # "Rigging I"
@export var stat_type: StatType
@export var tier: int = 1             # 1, 2, or 3
@export var icon: Texture2D
@export var max_level: int = 3
@export var level_costs: Array[int] = [5, 10, 15]   # cost for level 1, 2, 3
@export var bonus_per_level: float = 10.0
