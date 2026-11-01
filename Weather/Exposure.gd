extends RefCounted

# Called only by the authoritative simulation. This integrates regeneration and
# rain damage in chronological order, even if a tick crosses several events.
const GRACE_SECONDS := 40.0
const DAMAGE_INTERVAL := 15.0
var exposure_seconds: float = 0.0
var next_damage_at: float = GRACE_SECONDS + DAMAGE_INTERVAL
var damage_count: int = 0
var wetness: float = 0.0
var temperature: float = 37.0
var comfort: bool = false

func reset() -> void:
	exposure_seconds = 0.0
	next_damage_at = GRACE_SECONDS + DAMAGE_INTERVAL

func advance(delta: float, raining: bool, sheltered: bool, vitals,
		near_fire: bool = false) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	comfort = near_fire
	var exposed := raining and not sheltered
	if not exposed:
		reset()
		vitals.advance(delta)
	else:
		var destination := exposure_seconds + delta
		while next_damage_at <= destination + 0.00000001:
			vitals.advance(maxf(0.0, next_damage_at - exposure_seconds))
			exposure_seconds = next_damage_at
			vitals.damage(1)
			damage_count += 1
			next_damage_at += DAMAGE_INTERVAL
		vitals.advance(maxf(0.0, destination - exposure_seconds))
		exposure_seconds = destination
	var wet_rate := 1.0 / 80.0 if exposed else (-1.0 / 30.0 if near_fire else -1.0 / 120.0)
	wetness = clampf(wetness + wet_rate * delta, 0.0, 1.0)
	var target_temperature := 37.0 - wetness * (0.5 if near_fire else 3.5)
	temperature = lerpf(temperature, target_temperature, 1.0 - exp(-delta / 30.0))

func state() -> Dictionary:
	return {"exposure": exposure_seconds, "wetness": wetness,
		"temperature": temperature, "comfort": comfort, "rain_damage": damage_count}

func restore(data: Dictionary) -> void:
	if not valid(data):
		return
	exposure_seconds = float(data["exposure"])
	wetness = float(data["wetness"])
	temperature = float(data["temperature"])
	damage_count = int(data["rain_damage"])
	comfort = bool(data.get("comfort", false))
	next_damage_at = GRACE_SECONDS + DAMAGE_INTERVAL
	if exposure_seconds >= next_damage_at:
		next_damage_at += (floorf((exposure_seconds - next_damage_at) / DAMAGE_INTERVAL) + 1.0) * DAMAGE_INTERVAL

static func valid(data: Dictionary) -> bool:
	for key in ["exposure", "wetness", "temperature", "rain_damage"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	if float(data["exposure"]) < 0 or float(data["exposure"]) > 1000000000:
		return false
	if float(data["wetness"]) < 0 or float(data["wetness"]) > 1:
		return false
	if float(data["temperature"]) < 0 or float(data["temperature"]) > 50:
		return false
	return float(data["rain_damage"]) >= 0 and float(data["rain_damage"]) <= 1000000000 \
		and float(data["rain_damage"]) == floorf(float(data["rain_damage"]))
