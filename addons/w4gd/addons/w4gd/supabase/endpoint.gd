## A Supabase REST end-point under a specific base path (ex. [code]/auth/v1/[/code] or [code]/storage/v1/[/code]).
extends RefCounted
class_name W4APIEndpoint

## The REST client.
var client : W4HTTPClient
## The base path.
var endpoint := ""
## The Supabase identity.
var identity : W4Identity

func _init(p_client: W4HTTPClient, p_endpoint: String, p_identity: W4Identity):
	client = p_client
	endpoint = p_endpoint
	identity = p_identity


func _null_stripped(from : Dictionary) -> Dictionary:
	var out := {}
	for k in from:
		if typeof(from[k]) == TYPE_NIL:
			continue
		out[k] = from[k]
	return out


## Parses a result from the REST client into a W4APIResult.
static func parse_result(result: W4HTTPResult, binary:=false) -> W4APIResult:
	return W4APIResult.parse_result(result, binary)


## Parses the result of a HEAD request from the REST client into a W4APIResult.
static func _parse_head_result(result: W4HTTPResult) -> W4APIResult:
	if result.is_http_success():
		return W4APIResult.new(result.dict_headers())
	return W4APIResult.parse_result(result, true)


## Makes a GET request.
func GET(path, query : Dictionary = {}, extra_headers : Dictionary = {}, binary:=false) -> W4APIRequest:
	return client.GET(endpoint + path, query, extra_headers).then(parse_result.bind(binary))


## Makes a HEAD request.
func HEAD(path, query : Dictionary = {}, extra_headers : Dictionary = {}) -> W4APIRequest:
	return client.HEAD(endpoint + path, query, extra_headers).then(_parse_head_result)


## Makes a raw GET request, that returns binary data.
func GET_RAW(path, query : Dictionary = {}, extra_headers : Dictionary = {}) -> W4APIRequest:
	return client.GET(endpoint + path, query, extra_headers).then(parse_result.bind(true))


## Makes a POST request.
func POST(path, data = null, query : Dictionary = {}, extra_headers : Dictionary = {}, binary:=false) -> W4APIRequest:
	return client.POST(endpoint + path, data, query, extra_headers).then(parse_result.bind(binary))


## Makes a PUT request.
func PUT(path, data = null, query : Dictionary = {}, extra_headers : Dictionary = {}, binary:=false) -> W4APIRequest:
	return client.PUT(endpoint + path, data, query, extra_headers).then(parse_result.bind(binary))


## Makes a PATCH request.
func PATCH(path, data = null, query : Dictionary = {}, extra_headers : Dictionary = {}, binary:=false) -> W4APIRequest:
	return client.PATCH(endpoint + path, data, query, extra_headers).then(parse_result.bind(binary))


## Makes a DELETE request.
func DELETE(path, data = null, query : Dictionary = {}, extra_headers : Dictionary = {}, binary:=false) -> W4APIRequest:
	return client.DELETE(endpoint + path, data, query, extra_headers).then(parse_result.bind(binary))
