class_name ShopCatalog
extends RefCounted

## UI-facing catalogue only. Prices are placeholders until gameplay balancing
## provides authoritative values. No purchase or inventory logic lives here.

const WEAPONS := "Weapons"
const AUGMENTS := "Augments"
const POTIONS := "Potions"

const CATEGORIES := [WEAPONS, AUGMENTS, POTIONS]


static func get_items(category: String) -> Array:
	match category:
		WEAPONS:
			return _weapons()
		AUGMENTS:
			return _augments()
		POTIONS:
			return _potions()
	return []


static func _entry(
	id: String,
	display_name: String,
	category: String,
	subtype: String,
	icon_path: String,
	description: String,
	effects: Array,
	stats: Array,
	price: int,
	rarity: String = "COMMON",
	state: String = "available"
) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"category": category,
		"subtype": subtype,
		"icon": icon_path,
		"description": description,
		"effects": effects,
		"stats": stats,
		"price": price,
		"rarity": rarity,
		"state": state,
		"level": 1,
	}


static func _weapons() -> Array:
	return [
		_entry(
			"cannon", "CANNON", WEAPONS, "Starting Weapon",
			"res://Assets/UI/Shop/Items/Weapons/cannon.png",
			"The ship's dependable starting cannon. Simple, direct and ready for specialised augments.",
			["Main starting weapon", "Fires standard cannonballs forward"],
			[["damage", "STANDARD"], ["fire_rate", "0.5s"], ["projectile_speed", "1100"]],
			0, "COMMON", "owned"
		),
		_entry(
			"molotov", "MOLOTOV", WEAPONS, "Timed Area Weapon",
			"res://Assets/UI/Shop/Items/Weapons/molotov.png",
			"A volatile bottle thrown automatically in a random direction from the ship.",
			["Fires on a timer", "Creates burning area damage", "Burns for a limited duration"],
			[["burning", "AREA BURN"], ["duration", "TIMED"], ["area", "MEDIUM"]],
			250, "UNCOMMON"
		),
		_entry(
			"net", "NET", WEAPONS, "Timed Control Weapon",
			"res://Assets/UI/Shop/Items/Weapons/net.png",
			"A weighted net thrown like a Molotov, trading damage for control of crowded waters.",
			["Fires on a timer", "Thrown in a random direction", "Slows enemies inside the net", "Deals no base damage"],
			[["slow", "STRONG"], ["area", "MEDIUM"], ["damage", "NONE"]],
			225, "UNCOMMON"
		),
		_entry(
			"side_cannons", "SIDE CANNONS", WEAPONS, "Concept Weapon",
			"res://Assets/UI/Shop/Items/Weapons/side_cannons.png",
			"A possible broadside weapon firing from both sides of the player ship.",
			["Team concept — final behaviour not yet confirmed", "Prepared as a UI placeholder only"],
			[["multishot", "BROADSIDE"], ["range", "TBD"]],
			0, "RARE", "locked"
		),
		_entry(
			"harpoon", "HARPOON", WEAPONS, "Tracking Pierce Weapon",
			"res://Assets/UI/Shop/Items/Weapons/harpoon.png",
			"A naval harpoon that seeks the closest target and keeps travelling through the enemy line.",
			["Targets the nearest enemy", "Infinite pierce", "Continues until it leaves the screen"],
			[["homing", "NEAREST"], ["piercing", "INFINITE"], ["range", "SCREEN"]],
			450, "RARE"
		),
		_entry(
			"chain_shot", "CHAIN SHOT", WEAPONS, "Heavy Control Weapon",
			"res://Assets/UI/Shop/Items/Weapons/chain_shot.png",
			"Two iron balls linked by chain, launched at a random nearby ship to cripple its movement.",
			["Targets a random enemy in range", "Heavy hit", "Slows the target", "Does not pierce"],
			[["damage", "HEAVY"], ["slow", "STRONG"], ["piercing", "NONE"]],
			400, "RARE"
		),
		_entry(
			"sulfur_stinkpots", "SULFUR STINKPOTS", WEAPONS, "Gas Area Weapon",
			"res://Assets/UI/Shop/Items/Weapons/sulfur_stinkpot.png",
			"Sulfur-filled pots burst into lingering clouds that wear enemies down over time.",
			["Creates a damaging gas cloud", "Deals damage over time", "Fire damage may ignite the cloud for an AOE explosion"],
			[["poison", "DAMAGE OVER TIME"], ["area", "GAS CLOUD"], ["duration", "LINGERING"]],
			500, "EPIC"
		),
	]


static func _augments() -> Array:
	return [
		# Cannon
		_entry("plasma_cannon", "PLASMA CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/plasma_cannon.png", "Infuses cannon fire with volatile Azure plasma.", ["Exact plasma behaviour and values are still being decided"], [["damage", "TBD"], ["area", "PLASMA"]], 180, "RARE"),
		_entry("homing_cannon", "HOMING CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/homing_cannon.png", "Enchanted cannonballs correct their flight toward enemy ships.", ["Cannonballs track enemies", "Improves hit reliability"], [["homing", "ENABLED"], ["range", "TARGETED"]], 200, "RARE"),
		_entry("fire_cannon", "FIRE CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/fire_cannon.png", "Heated shot sets struck targets alight.", ["Adds a burning effect to cannon hits"], [["burning", "ENABLED"], ["duration", "TIMED"]], 190, "UNCOMMON"),
		_entry("piercing_cannon", "PIERCING CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/piercing_cannon.png", "Reinforced ammunition punches through enemy formations.", ["Cannonballs pierce enemies"], [["piercing", "ENABLED"], ["damage", "LINE"]], 190, "UNCOMMON"),
		_entry("multishot_cannon", "MULTISHOT CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/multishot_cannon.png", "Splits each firing cycle into several cannonballs.", ["Fires multiple cannonballs per shot"], [["multishot", "ENABLED"], ["area", "SPREAD"]], 225, "RARE"),
		_entry("chain_lightning_cannon", "CHAIN LIGHTNING CANNON", AUGMENTS, "Homing + Plasma Combination", "res://Assets/UI/Shop/Items/Augments/Cannon/chain_lightning_cannon.png", "A discovered combination that carries plasma between nearby targets.", ["Combination: Homing Cannon + Plasma Cannon", "Chains lightning between targets"], [["homing", "CHAIN"], ["damage", "PLASMA"]], 0, "EPIC", "combination"),
		_entry("laser_cannon", "LASER CANNON", AUGMENTS, "Plasma + Rapid Fire Combination", "res://Assets/UI/Shop/Items/Augments/Cannon/laser_cannon.png", "Rapid plasma converges into a concentrated beam.", ["Combination: Plasma Cannon + Rapid Fire", "Produces a laser-style attack"], [["fire_rate", "RAPID"], ["damage", "PLASMA BEAM"]], 0, "EPIC", "combination"),
		_entry("grape_cannon", "GRAPE CANNON", AUGMENTS, "Cannon Augment", "res://Assets/UI/Shop/Items/Augments/Cannon/grape_cannon.png", "A broad spray of smaller shot that can inherit the cannon's other augments.", ["Shotgun-like spread", "Lower damage per pellet", "Benefits from other cannon augments"], [["multishot", "WIDE SPREAD"], ["damage", "LOW / PELLET"]], 260, "EPIC"),

		# Molotov
		_entry("tequila", "TEQUILA", AUGMENTS, "Molotov Augment", "res://Assets/UI/Shop/Items/Augments/Molotov/tequila.png", "A fast, furious burn for the Molotov.", ["Burns quicker", "Burns hotter"], [["burning", "FAST / HOT"], ["duration", "SHORTER"]], 140, "UNCOMMON"),
		_entry("rum", "RUM", AUGMENTS, "Molotov Augment", "res://Assets/UI/Shop/Items/Augments/Molotov/rum.png", "Slow-burning rum keeps the flames alive for longer.", ["Extends burn duration"], [["duration", "LONGER"], ["burning", "SUSTAINED"]], 140, "UNCOMMON"),
		_entry("liqueur", "LIQUEUR", AUGMENTS, "Molotov Augment", "res://Assets/UI/Shop/Items/Augments/Molotov/liqueur.png", "A potent blend that strengthens the Molotov's burn.", ["Stronger burn damage"], [["damage", "INCREASED"], ["burning", "STRONGER"]], 160, "RARE"),

		# Net
		_entry("reinforced_net", "REINFORCED NET", AUGMENTS, "Net Augment", "res://Assets/UI/Shop/Items/Augments/Net/reinforced_net.png", "Heavier rope and weights improve the net; its exact bonus is still to be confirmed.", ["Reinforced net", "Final slow or duration bonus is TBD"], [["slow", "TBD"], ["duration", "TBD"]], 150, "UNCOMMON"),
		_entry("more_rope_net", "MORE ROPE NET", AUGMENTS, "Net Augment", "res://Assets/UI/Shop/Items/Augments/Net/more_rope_net.png", "More rope spreads the net over a larger part of the sea.", ["Increases net size"], [["area", "LARGER"]], 150, "UNCOMMON"),
		_entry("moving_net", "FLOATING NET", AUGMENTS, "Net Augment", "res://Assets/UI/Shop/Items/Augments/Net/floating_net.png", "The deployed net floats or moves instead of remaining fixed.", ["Net can float or move", "Exact movement pattern is TBD"], [["area", "MOVING"], ["duration", "TBD"]], 190, "RARE"),
		_entry("poison_net", "POISON NET", AUGMENTS, "Net Augment", "res://Assets/UI/Shop/Items/Augments/Net/poison_net.png", "Poisoned rope hurts ships caught inside the net.", ["Adds poison damage to trapped enemies"], [["poison", "ENABLED"], ["slow", "ENABLED"]], 210, "RARE"),

		# Harpoon
		_entry("boomerang_harpoon", "BOOMERANG HARPOON", AUGMENTS, "Harpoon Augment", "res://Assets/UI/Shop/Items/Augments/Harpoon/boomerang_harpoon.png", "The harpoon returns when it reaches the end of its trajectory.", ["Returns to its launch position or the player"], [["homing", "RETURN"], ["piercing", "OUT + BACK"]], 210, "RARE"),
		_entry("bouncy_harpoon", "BOUNCY HARPOON", AUGMENTS, "Harpoon Augment", "res://Assets/UI/Shop/Items/Augments/Harpoon/bouncy_harpoon.png", "A reinforced head rebounds from the edges of the screen.", ["Bounces from screen boundaries"], [["range", "BOUNCING"], ["piercing", "ENABLED"]], 200, "RARE"),
		_entry("split_harpoon", "SPLIT HARPOON", AUGMENTS, "Harpoon Augment", "res://Assets/UI/Shop/Items/Augments/Harpoon/split_harpoon.png", "The main shaft breaks into three smaller harpoons on impact.", ["Splits into three", "Triggers on enemy or wall impact", "Splits only once"], [["multishot", "3-WAY SPLIT"], ["piercing", "SPLIT"]], 240, "EPIC"),
		_entry("explosive_harpoon", "EXPLOSIVE HARPOON", AUGMENTS, "Harpoon Augment", "res://Assets/UI/Shop/Items/Augments/Harpoon/explosive_harpoon.png", "A timed charge replaces the harpoon's normal piercing behaviour.", ["Removes piercing", "Sticks into an enemy", "Detonates after a delay"], [["piercing", "REMOVED"], ["area", "EXPLOSION"], ["duration", "FUSE"]], 240, "EPIC"),
		_entry("chain_lightning_harpoon", "CHAIN LIGHTNING HARPOON", AUGMENTS, "Harpoon Augment", "res://Assets/UI/Shop/Items/Augments/Harpoon/chain_lightning_harpoon.png", "The harpoon seeks a new target after each strike.", ["Chains between targets", "Proposed limit: three targets", "Final bounce behaviour is still TBD"], [["homing", "CHAIN"], ["range", "3 TARGETS"]], 275, "EPIC"),
		_entry("skewer_harpoon", "SKEWER HARPOON", AUGMENTS, "Explosive + Chain Combination", "res://Assets/UI/Shop/Items/Augments/Harpoon/skewer_harpoon.png", "A brutal combination that drags previous victims through the chain before exploding.", ["Combination: Explosive + Chain Lightning", "Pulls previous victims", "Explodes at the chain limit"], [["pull_strength", "CHAIN PULL"], ["area", "FINAL EXPLOSION"]], 0, "LEGENDARY", "combination"),

		# Chain shot and stinkpots
		_entry("heavy_balls", "HEAVY BALLS", AUGMENTS, "Chain Shot Augment", "res://Assets/UI/Shop/Items/Augments/ChainShot/heavy_balls.png", "Heavier iron balls hit harder and cripple movement more severely.", ["Increases damage", "Increases slowing strength"], [["damage", "HIGHER"], ["slow", "STRONGER"]], 180, "RARE"),
		_entry("stinkpot_multishot", "MULTISHOT STINKPOTS", AUGMENTS, "Stinkpot Augment", "res://Assets/UI/Shop/Items/Augments/Stinkpot/multishot.png", "Throws several sulfur stinkpots at once.", ["Adds multishot"], [["multishot", "ENABLED"], ["area", "MULTIPLE CLOUDS"]], 190, "RARE"),
		_entry("stronger_arms", "STRONGER ARMS", AUGMENTS, "Stinkpot Augment", "res://Assets/UI/Shop/Items/Augments/Stinkpot/stronger_arms.png", "A stronger throw sends stinkpots farther from the ship.", ["Increases throw distance"], [["range", "FARTHER"]], 140, "UNCOMMON"),
		_entry("stinkier_gases", "STINKIER GASSES", AUGMENTS, "Stinkpot Augment", "res://Assets/UI/Shop/Items/Augments/Stinkpot/stinkier_gases.png", "The smell clings to enemies after they escape the cloud.", ["Gas becomes a temporary status effect", "Continues after leaving the area"], [["duration", "LINGERING"], ["poison", "CLINGING"]], 190, "RARE"),
		_entry("deadly_gases", "DEADLY GASSES", AUGMENTS, "Stinkpot Augment", "res://Assets/UI/Shop/Items/Augments/Stinkpot/deadly_gases.png", "A larger, deadlier cloud dominates more of the battlefield.", ["Increases cloud size", "Increases damage"], [["area", "LARGER"], ["damage", "HIGHER"]], 225, "EPIC"),
	]


static func _potions() -> Array:
	return [
		_entry("rapid_fire_potion", "RAPID FIRE", POTIONS, "Potion", "res://Assets/UI/Shop/Items/Potions/rapid_fire.png", "A short-lived rush that lets the ship's weapons fire faster.", ["Temporarily increases fire rate"], [["fire_rate", "BOOSTED"], ["duration", "TEMPORARY"]], 90, "UNCOMMON"),
		_entry("shield_potion", "SHIELD", POTIONS, "Potion", "res://Assets/UI/Shop/Items/Potions/shield.png", "A protective draught that adds shield strength beyond normal health.", ["Adds shield"], [["shield", "ADDITIONAL"]], 100, "UNCOMMON"),
		_entry("health_potion", "HEALTH", POTIONS, "Potion", "res://Assets/UI/Shop/Items/Potions/health.png", "A restorative mixture for repairing damage at sea.", ["Restores player health"], [["health", "RESTORE"]], 80, "COMMON"),
		_entry("speed_time_potion", "SPEED / SLOW TIME", POTIONS, "Potion Concept", "res://Assets/UI/Shop/Items/Potions/speed_time.png", "Either boosts ship speed or slows the world around it; the team has not chosen the final version.", ["Option A: increase player speed", "Option B: globally slow camera scrolling and enemies"], [["movement_speed", "TBD"], ["duration", "TEMPORARY"]], 110, "RARE"),
		_entry("shrink_potion", "SHRINK", POTIONS, "Wonderland Potion", "res://Assets/UI/Shop/Items/Potions/shrink.png", "Temporarily shrinks the player ship.", ["Shrink effect", "Exact gameplay values are TBD"], [["area", "SMALLER PLAYER"], ["duration", "TEMPORARY"]], 100, "RARE"),
		_entry("growth_potion", "GROWTH", POTIONS, "Wonderland Potion", "res://Assets/UI/Shop/Items/Potions/growth.png", "Temporarily enlarges the player ship.", ["Growth effect", "Exact gameplay values are TBD"], [["area", "LARGER PLAYER"], ["duration", "TEMPORARY"]], 100, "RARE"),
		_entry("rubber_potion", "RUBBER", POTIONS, "Reflection Potion", "res://Assets/UI/Shop/Items/Potions/reflection.png", "Turns the hull rubbery enough to send incoming shots back where they came from.", ["Reflects enemy bullets toward their source", "Does not protect against contact damage"], [["shield", "PROJECTILES ONLY"], ["duration", "TEMPORARY"]], 160, "EPIC"),
	]
