extends RefCounted
class_name W4Utils

## Internal class used internally to generate v4 UUIDs.
class UUIDGenerator extends RefCounted:
	var crypto := Crypto.new()
	var rng := RandomNumberGenerator.new()

	func generate_v4() -> String:
		var b := PackedByteArray()
		if crypto == null:
			b.resize(16)
			for i in range(16):
				b[i] = rng.randi() % 256
		else:
			b = crypto.generate_random_bytes(16)
		b[6] = (b[6] & 0x0f) | 0x40
		b[8] = (b[8] & 0x3f) | 0x80
		return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
			b[0], b[1], b[2], b[3],
			b[4], b[5],
			b[6], b[7],
			b[8], b[9],
			b[10], b[11], b[12], b[13], b[14], b[15],
		]


static func get_current_time() -> String:
	# Get timestamp with sub-second precision.
	return get_time(Time.get_unix_time_from_system())


static func get_time(utc_timestamp: float) -> String:
	# If the time contains '.', split it and use part after '.' as subsecond, otherwise 0.
	var subsecond = "0" if str(utc_timestamp).find('.') < 0 else str(utc_timestamp).split('.')[1]
	return Time.get_datetime_string_from_unix_time(utc_timestamp, true) + '.' + subsecond + "+00:00"


static func parse_timestamptz(timestamp: String) -> float:
	# Parse unix time
	var unix := Time.get_unix_time_from_datetime_string(timestamp)
	# Expects PG format YYYY-MM-DD hh:mm:ss[.s+]+hh:ss
	# Parse subsecond and time zone
	var delta := 0
	var chr := timestamp.substr(timestamp.length() - 3, 1)
	if chr == ":":
		delta += timestamp.substr(-2).to_int()
		timestamp = timestamp.substr(0, timestamp.length() - 3)
		chr = timestamp.substr(timestamp.length() - 3, 1)
	if chr == "+" or chr == "-":
		delta += 60 * timestamp.substr(-2).to_int()
		if chr == "+":
			delta = -delta
	else:
		push_error("Invalid timestamptz")
		return 0.0
	timestamp = timestamp.substr(0, timestamp.length() - 3)
	var subsec := 0.0
	var idx := timestamp.find(".")
	if idx > 0:
		subsec = timestamp.substr(idx).to_float()
	return float(unix + (delta * 60)) + subsec


## Returns true if the given JWT token is valid; otherwise, false.
static func validate_jwt(p_token : String) -> bool:
	return _validate_token(p_token).size() > 0


## Parses the given JWT token.
static func parse_jwt(p_token : String) -> Dictionary:
	return _validate_token(p_token)


static func _b64_restore(p_b64url : String) -> String:
	var out = p_b64url.replace("-", "+").replace("_", "/")
	while out.length() % 4:
		out += "="
	return out


static func _parse_token_part(p_part : String, p_required : Array) -> Dictionary:
	var json_parser = JSON.new()
	if json_parser.parse(p_part):
		push_error("Failed to parse token: ", p_part)
		return {}
	var part = json_parser.get_data()
	if typeof(part) != TYPE_DICTIONARY:
		push_error("Failed to parse token: ", p_part)
		return {}
	for k in p_required:
		if k in part:
			continue
		push_error("Failed to parse token. Missing required key: ", k, " Part: ", p_part)
		return {}
	return part


static func _validate_token(p_token : String) -> Dictionary:
	var parts = p_token.split(".")
	if parts.size() != 3:
		push_error("Failed to parse token: ", p_token)
		return {}
	var header_json = Marshalls.base64_to_utf8(_b64_restore(parts[0]))
	var payload_json = Marshalls.base64_to_utf8(_b64_restore(parts[1]))
	var header = _parse_token_part(header_json, ["alg", "typ"])
	if header.is_empty():
		return {}
	var payload = _parse_token_part(payload_json, ["exp", "role"])
	if payload.is_empty():
		return {}
	return {
		"header": header,
		"payload": payload,
	}
