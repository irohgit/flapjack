class_name StatusEffectModifier
extends Resource


enum Operation {
	ADD,
	MULTIPLY,
}


@export var stat_id: StringName
@export var operation: Operation = Operation.ADD
@export var value := 0.0
