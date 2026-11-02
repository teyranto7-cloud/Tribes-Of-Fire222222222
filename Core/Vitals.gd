extends RefCounted

const MAX_HP := 100
const REGEN_INTERVAL := 3.0
var hp: int = MAX_HP
var quiet_seconds: float = 0.0
var regen_delay: float = 6.0
var regen_block_left: float = 0.0

func damage(amount: int) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	quiet_seconds = 0.0
	regen_block_left = regen_delay

func advance(delta: float, safe: bool = true) -> void:
	if hp <= 0 or not is_finite(delta) or delta <= 0:
		return
	var available := maxf(0.0, delta - regen_block_left)
	regen_block_left = maxf(0.0, regen_block_left - delta)
	# Unsafe exposure/combat cannot bank partial regeneration for an instant heal.
	if not safe:
		quiet_seconds = 0.0
		return
	quiet_seconds += available
	var ticks := int(floor((quiet_seconds + 0.00000001) / REGEN_INTERVAL))
	if ticks > 0:
		quiet_seconds = maxf(0.0, quiet_seconds - ticks * REGEN_INTERVAL)
		hp = mini(MAX_HP, hp + ticks)
