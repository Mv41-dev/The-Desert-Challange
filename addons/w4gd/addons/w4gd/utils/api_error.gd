extends RefCounted
class_name W4APIError
## Common error type for most results.
## [codeblock]
## var request : W4APIRequest = W4GD.login_email("user@example.com", "password")
## var result : W4APIResult = await request.async()
## if result.is_error():
##     var error : W4APIError = result.as_error()
## [/codeblock]

## The error code (usually the HTTP response code).
var error := 0
## The application error code (usually parsed from json body)
var code := 0
## The error message.
var message := ""
## The error data.
var data : Variant = null

func _init(p_error: int, p_message:="", p_data:Variant=null):
	error = p_error
	code = p_error
	message = p_message
	data = p_data
	_parse_error_data(p_data)


func _parse_error_data(p_data:Variant):
	if typeof(p_data) != TYPE_DICTIONARY:
		return
	if type_convert(p_data.get("code", 0), TYPE_INT) != 0:
		code = int(p_data["code"])
	if type_convert(p_data.get("statusCode", 0), TYPE_INT) != 0:
		code = int(p_data["statusCode"])
	message = str(p_data.get("reason", message))
	message = str(p_data.get("error", message))
	message = str(p_data.get("error_description", message))
	message = str(p_data.get("msg", message))
	message = str(p_data.get("message", message))


func _to_string() -> String:
	return "Error%s" % {
		"error": error,
		"code": code,
		"message": message,
		"data": data if typeof(data) != TYPE_PACKED_BYTE_ARRAY else (str(data.slice(0, 256)) + "..."),
	}
