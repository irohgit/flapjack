class_name Groups
extends RefCounted

## Single source of truth for every group name in Flapjack.
## Never type a group name as a raw string anywhere else.
## Adding a constant here does NOT create the group. You still add the node
## to the group in the Node panel, or call add_to_group() in code.
const PLAYER := &"player"
const SHIP_MESSAGE := &"ship_message"
const ENEMY := &"enemy"
const HOTSPOT := &"hotspot"
const STAGE_TITLE := &"stage_title"
