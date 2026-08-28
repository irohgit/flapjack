class_name ShopData
extends Resource

## Per-level merchant stock. Each visit rolls a distinct subset of the pool.

const MIN_ALLOWED_OFFERS := 1
const MAX_ALLOWED_OFFERS := 5

@export_range(MIN_ALLOWED_OFFERS, MAX_ALLOWED_OFFERS, 1) var min_offers := 3
@export_range(MIN_ALLOWED_OFFERS, MAX_ALLOWED_OFFERS, 1) var max_offers := 5
@export var offer_pool: Array[ShopOfferData] = []


func roll_offers(rng: RandomNumberGenerator = null) -> Array[ShopOfferData]:
	var roller := rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()

	var candidates: Array[ShopOfferData] = []
	for offer in offer_pool:
		if offer != null and offer.is_valid():
			candidates.append(offer)

	var rolled: Array[ShopOfferData] = []
	if candidates.is_empty():
		return rolled

	var highest_count := mini(clampi(max_offers, MIN_ALLOWED_OFFERS, MAX_ALLOWED_OFFERS), candidates.size())
	var lowest_count := mini(clampi(min_offers, MIN_ALLOWED_OFFERS, highest_count), highest_count)
	var roll_count := roller.randi_range(lowest_count, highest_count)

	for _index in roll_count:
		var selected_index := _weighted_index(candidates, roller)
		rolled.append(candidates.pop_at(selected_index))

	return rolled


func _weighted_index(candidates: Array[ShopOfferData], rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	for offer in candidates:
		total_weight += maxf(offer.weight, 0.0)

	if total_weight <= 0.0:
		return rng.randi_range(0, candidates.size() - 1)

	var roll := rng.randf_range(0.0, total_weight)
	for index in candidates.size():
		roll -= maxf(candidates[index].weight, 0.0)
		if roll <= 0.0:
			return index

	return candidates.size() - 1
