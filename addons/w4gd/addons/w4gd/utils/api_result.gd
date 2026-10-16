extends RefCounted
class_name W4APIResult
## Common result type for most of the SDK requests.
## [codeblock]
## var request : W4APIRequest = W4GD.login_email("user@example.com", "password")
## var result : W4APIResult = await request.async()
## [/codeblock]
##
## W4APIResult wraps some piece of data, which can be almost any type, including Object,
## ResultError, Dictionary, Array, PackedByteArray, String, int, float, or bool.
##
## Use the [code]is_*()[/code] methods (like [code]is_dict()[/code] to check the type,
## or the [code]as_*()[/code] methods (like [code]as_dict()[/code] to get the data in
## the given type (or some "zero" version of that type if it's a different type).
##
## You can also refer to sub-properties of the wrapped data, and get them as a new
## W4APIResult object. For example:
##
## [codeblock]
## var dict := {
##   key = "a string"
## }
## var result = W4APIResult.new(dict)
## print(result.key.as_string())
## [/codeblock]

var _data = null
var _result : W4HTTPResult = null

func _init(data=null, result=null):
	_data = data
	_result = result


func _to_string() -> String:
	return str(_data) if not is_byte_array() else (str(_data.slice(0, 256)) + "...")


func _get(property: StringName):
	if property == &"_data":
		return _data
	elif property == &"_result":
		return _result
	elif property == &"script" or property == &"Built-in script":
		# Avoid breaking debug.
		return get_script()
	elif property == &"RefCounted":
		return null
	var err = "Unknown"
	if is_dict():
		if property in _data:
			return new(_data[property])
		err = "Property %s not found in data." % property
	elif is_array() or is_byte_array():
		if str(property).is_valid_int():
			return get_at(str(property).to_int())
		err = "Array access not supported yet. Use get_at(idx) for now"
	elif is_error():
		return new(_data.get(property))
	else:
		err = "Unsupported data type %d" % typeof(_data)
	push_error(err, property, _to_string())
	return new(W4APIError.new(-1, err, _data))


## Returns a new W4APIResult for the item at the given index.
##
## If the wrapped data isn't an Array or PackedByteArray, or the index is
## out of bounds, it will return a wrapped ResultError object.
func get_at(idx : int):
	var err = "Error: 'get_at'. "
	if not is_array() and not is_byte_array():
		err += "Can't use 'get_at(idx)' on non array type (type=%d)" % typeof(_data)
	elif idx < 0 or _data.size() <= idx:
		err += "Invalid index %s, size: %s" % [idx, _data.size()]
	else:
		return new(_data[idx])
	push_error(err, _to_string())
	return new(W4APIError.new(-1, err, _data))


## Returns the size or length of the wrapped data.
##
## If the wrapped data isn't a Dictionary, Array or String, it will
## return 0;
func size() -> int:
	if is_array() or is_dict():
		return _data.size()
	if is_string():
		return _data.length()
	return 0


## Returns an Array of the keys from the wrapped data.
##
## If the wrapped data isn't a Dictionary, it will return an empty Array.
func keys() -> Array:
	if is_dict():
		return _data.keys()
	return []


## Returns an Array of the values from the wrapped data.
##
## If the wrapped data isn't an Array or Dictionary, it will return an empty Array.
func values() -> Array:
	if is_array():
		return _data
	if is_dict():
		return _data.values()
	return []


## Returns the wrapped data.
func get_data():
	return _data


## Returns true if the wrapped data is empty; otherwise, false.
func is_empty() -> bool:
	if is_array() or is_dict() or is_string():
		return _data.is_empty()
	return is_null()


## Returns true if the wrapped data is [code]null[/code]; otherwise, false.
func is_null() -> bool:
	return _data == null


## Returns true if the wrapped data is a string; otherwise, false.
func is_string() -> bool:
	return typeof(_data) == TYPE_STRING


## Returns true if the wrapped data is a Dictionary; otherwise, false.
func is_dict() -> bool:
	return typeof(_data) == TYPE_DICTIONARY


## Returns true if the wrapped data is an Array; otherwise, false.
func is_array() -> bool:
	return typeof(_data) == TYPE_ARRAY


## Returns true if the wrapped data is a PackedByteArray; otherwise, false.
func is_byte_array() -> bool:
	return typeof(_data) == TYPE_PACKED_BYTE_ARRAY


## Returns true if the wrapped data is a ResultError; otherwise, false.
func is_error() -> bool:
	return typeof(_data) == TYPE_OBJECT and _data is W4APIError


## Returns true if the wrapped data is an int; otherwise, false.
func is_int() -> bool:
	return typeof(_data) == TYPE_INT


## Returns true if the wrapped data is a float; otherwise, false.
func is_float() -> bool:
	return typeof(_data) == TYPE_FLOAT


## Returns true if the wrapped data is a bool; otherwise, false.
func is_bool() -> bool:
	return typeof(_data) == TYPE_BOOL


## Returns the wrapped data as a ResultError.
##
## If the wrapped data isn't a ResultError, it will return [code]null[/code].
func as_error() -> W4APIError:
	return _data if is_error() else null


## Returns the wrapped data as a Dictionary.
##
## If the wrapped data isn't a Dictionary, it will return an empty Dictionary.
func as_dict() -> Dictionary:
	return _data if is_dict() else {}


## Returns the wrapped data as an Array.
##
## If the wrapped data isn't an Array, it will return an empty Array.
func as_array() -> Array:
	return _data if is_array() else []


## Returns the wrapped data as a PackedByteArray.
##
## If the wrapped data isn't a PackedByteArray, it will return an empty PackedByteArray.
func as_bytes() -> PackedByteArray:
	return _data if is_byte_array() else PackedByteArray()


## Returns the wrapped data as a String.
##
## If the wrapped data is a bool, int or float, it will be converted to a String.
##
## If the wrapped data isn't a String or any of those, it will return an empty String.
func as_string() -> String:
	return str(_data) if is_string() or is_bool() or is_int() or is_float() else ""


## Returns the wrapped data as an int.
##
## If the wrapped data is a bool or float, it will be converted to an int.
##
## If the wrapped data isn't an int or any of those, it will return [code]0[/code].
func as_int() -> int:
	return int(_data) if is_bool() or is_int() or is_float() else 0


## Returns the wrapped data as a float.
##
## If the wrapped data is a bool or int, it will be converted to a float.
##
## If the wrapped data isn't a float or any of those, it will return [code]0.0[/code].
func as_float() -> float:
	return float(_data) if is_bool() or is_int() or is_float() else 0.0


## Returns the wrapped data as a bool.
##
## If the wrapped data is a int or float, it will be converted to a bool.
##
## If the wrapped data isn't a bool or any of those, it will return [code]false[/code].
func as_bool() -> bool:
	return bool(_data) if is_bool() or is_int() or is_float() else false


## Returns the headers from the HTTP result associated with this W4APIResult.
##
## If there is no associated HTTP result, it will return an empty Dictionary.
func get_headers() -> Dictionary:
	return _result.dict_headers() if _result != null else {}


## Returns the HTTP result associated with this W4APIResult.
##
## If there is no associated HTTP result, it will return [code]null[/code].
func get_http_result():
	return _result


## Parses an HTTP result into a W4APIResult.
##
## If [param p_raw] is [code]false[/code] (the default) then the response body will be parsed as JSON,
## and wrapped in the W4APIResult. Otherwise, the body will be wrapped in the W4APIResult as a PackedByteArray.
static func parse_result(result : W4HTTPResult, p_raw:=false) -> W4APIResult:
	if result.is_error():
		return new(W4APIError.new(result.http_request_result, "Network Error", result), result)
	elif result.is_cancelled():
		return new(W4APIError.new(result.http_request_result, "The request was cancelled", result), result)
	elif result.is_http_success():
		if p_raw: return new(result.bytes_result(), result)
		return new(result.json_result() if result.body.size() else null, result)
	elif result.is_http_redirect():
		return new(null, result)
	elif p_raw:
		return new(W4APIError.new(result.get_http_status_code(), "HTTP Error", result.bytes_result()), result)

	var json := result.json_result()
	var error := result.get_http_status_code()
	var msg := "Unknown error"
	if typeof(json) != TYPE_DICTIONARY:
		# So that we have _something_ from the remote server that might give a
		# clue as to the error, use the text content of the result.
		json = result.text_result()

	return new(W4APIError.new(error, msg, json), result)
