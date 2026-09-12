class_name LevelData
extends Resource

@export_group("Playfield")
@export var playfield_size: Vector2 = Vector2(1920.0, 1080.0)


@export_group("Stage")
## Stable identifier used by enemy drop tables. Unlike level_name, this should
## not change when the display name is edited.
@export var level_id: StringName = &""
@export var level_name: String = ""
@export var end_position: Vector2 = Vector2(0, -10000)
@export var spawn_ahead_distance: float = 600.0

@export_group("Merchant")
@export var shop_items: Array[PickupData] = []

@export_group("Encounter Sequence")
@export var encounter_sequence: Array[EncounterData] = []

@export_group("Stage Finale")
@export var finale_trigger_position: Vector2 = Vector2(0, -9000)
@export var finale_spawn_position: Vector2 = Vector2(0, -9600)
@export var finale_pool: Array[WeightedEndEventData] = []

#GIN
@export_group("Gin")
@export var gin_min := 6
@export var gin_max := 16
@export var brown_barrel: DestructibleData
@export var brown_value := 1        # gin this tier is worth
@export var gold_barrel: DestructibleData
@export var gold_value := 5
@export_range(0.0, 1.0) var gold_share := 0.5   # fraction of the total delivered as gold
@export var max_barrels_per_encounter := 4

@export_group("Presentation")
## Shown as the chapter card when the stage begins. Empty shows no card.
@export var stage_title := ""
@export var stage_subtitle := ""
@export_range(0.5, 6.0, 0.1) var title_hold := 2.0

func get_playfield_center() -> Vector2:
	return playfield_size * 0.5


func get_level_id() -> StringName:
	return level_id if level_id != &"" else StringName(level_name)
