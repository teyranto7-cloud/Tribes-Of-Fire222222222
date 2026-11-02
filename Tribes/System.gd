extends RefCounted
## All mutations run on the authority. Protection uses stable identities and UTC expiry.
const MAX_MEMBERS := 100
const MAX_PROTECTIONS := 2048
const PROTECTION_SECONDS := 300.0
var tribes: Dictionary = {}
var invitations: Dictionary = {}
var protections: Array = []

func tribe_of(key: String) -> String:
	for id in tribes:
		if key in tribes[id]["members"]:
			return id
	return ""

func command(actor: String, action: String, data: Dictionary, now: float = -1.0) -> bool:
	if now < 0:
		now = Time.get_unix_time_from_system()
	if not is_finite(now):
		return false
	# Capacity checks must see only live protection; stale entries never block leaving.
	protections = protections.filter(func(p): return float(p["until"]) > now)
	var id := tribe_of(actor)
	var target := str(data.get("target", ""))
	match action:
		"tribe_create":
			var title := str(data.get("name", "")).strip_edges()
			if id != "" or title.length() < 3 or title.length() > 32 or tribes.size() >= 64:
				return false
			id = Crypto.new().generate_random_bytes(16).hex_encode()
			tribes[id] = {"name": title, "leader": actor, "members": [actor]}
		"tribe_invite":
			if id == "" or tribes[id]["leader"] != actor or target == "" or tribe_of(target) != "":
				return false
			invitations[target] = {"tribe": id, "until": now + 600}
		"tribe_accept":
			var invite: Dictionary = invitations.get(actor, {})
			if id != "" or invite.is_empty() or float(invite["until"]) < now or not tribes.has(invite["tribe"]):
				return false
			if tribes[invite["tribe"]]["members"].size() >= MAX_MEMBERS:
				return false
			tribes[invite["tribe"]]["members"].append(actor)
			invitations.erase(actor)
		"tribe_leave", "tribe_kick":
			var departing := actor if action == "tribe_leave" else target
			if id == "" or (action == "tribe_kick" and (tribes[id]["leader"] != actor or target == actor or not target in tribes[id]["members"])):
				return false
			var former_members: Array = tribes[id]["members"].duplicate()
			former_members.erase(departing)
			if not former_members.is_empty():
				var existing := _equivalent_protection(departing, id, former_members)
				if existing < 0 and protections.size() >= MAX_PROTECTIONS:
					# Refuse before changing membership or dropping any live protection.
					return false
				if existing >= 0:
					protections[existing]["until"] = maxf(float(protections[existing]["until"]), now + PROTECTION_SECONDS)
				else:
					protections.append({"person": departing, "tribe": id, "members": former_members, "until": now + PROTECTION_SECONDS})
			tribes[id]["members"].erase(departing)
			if tribes[id]["members"].is_empty():
				tribes.erase(id)
			elif tribes[id]["leader"] == departing:
				tribes[id]["leader"] = tribes[id]["members"][0]
		"tribe_leader":
			if id == "" or tribes[id]["leader"] != actor or not target in tribes[id]["members"]:
				return false
			tribes[id]["leader"] = target
		_:
			return false
	return true

func _equivalent_protection(person: String, tribe: String, members: Array) -> int:
	for index in range(protections.size()):
		var existing: Dictionary = protections[index]
		if existing["person"] != person or existing["tribe"] != tribe:
			continue
		# Legacy v3 records also stored the departing player in this array.
		var previous: Array = existing["members"].filter(func(member): return member != person)
		if previous.size() != members.size():
			continue
		var equivalent := true
		for member in members:
			if not member in previous:
				equivalent = false
				break
		if equivalent:
			return index
	return -1

func can_damage(a: String, b: String, now: float = -1.0) -> bool:
	if a == b:
		return false
	if now < 0:
		now = Time.get_unix_time_from_system()
	var ta := tribe_of(a)
	var tb := tribe_of(b)
	if ta != "" and ta == tb:
		return false
	for p in protections:
		if float(p["until"]) <= now:
			continue
		if (a == p["person"] and (b in p["members"] or tb == p["tribe"])) or (b == p["person"] and (a in p["members"] or ta == p["tribe"])):
			return false
	return true

func can_build(owner: String, actor: String) -> bool:
	return owner == actor or (tribe_of(owner) != "" and tribe_of(owner) == tribe_of(actor))

func state() -> Dictionary:
	return {"tribes": tribes.duplicate(true), "invitations": invitations.duplicate(true), "protections": protections.duplicate(true)}

func restore(data: Dictionary) -> void:
	if valid_state(data):
		tribes = data["tribes"].duplicate(true)
		invitations = data["invitations"].duplicate(true)
		protections = data["protections"].duplicate(true)

static func valid_state(data: Dictionary) -> bool:
	if not data.get("tribes") is Dictionary or data["tribes"].size() > 64 or not data.get("invitations") is Dictionary or data["invitations"].size() > 1024 or not data.get("protections") is Array or data["protections"].size() > MAX_PROTECTIONS:
		return false
	for id in data["tribes"]:
		var t: Variant = data["tribes"][id]
		if not id is String or not t is Dictionary or not t.get("name") is String or t["name"].length() > 32 or not t.get("members") is Array or t["members"].size() > MAX_MEMBERS or not t.get("leader") in t["members"]:
			return false
		for member in t["members"]:
			if not member is String or member.length() > 128:
				return false
	for p in data["protections"]:
		if not p is Dictionary or not p.get("person") is String or not p.get("tribe") is String or not p.get("members") is Array or p["members"].size() > MAX_MEMBERS or not (p.get("until") is float or p.get("until") is int) or not is_finite(float(p["until"])):
			return false
	for key in data["invitations"]:
		var invite: Variant = data["invitations"][key]
		if not key is String or not invite is Dictionary or not invite.get("tribe") is String or not (invite.get("until") is float or invite.get("until") is int) or not is_finite(float(invite["until"])):
			return false
	return true
