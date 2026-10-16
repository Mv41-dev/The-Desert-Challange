## The Supabase Storage end-point at /storage/v1.
extends W4APIEndpoint
class_name W4SupabaseStorage

const Mime = preload("mime_types.gd")

## The sort order.
enum SortOrder {ASC, DESC}

## Checks the status of the storage service.
func get_status() -> W4APIRequest:
	return GET("/status")


## Creates a new bucket with the given name.
func create_bucket(p_name: String, p_public:=false, p_id:="") -> W4APIRequest:
	return POST("/bucket", {
		"name": p_name,
		"id": p_name if p_id.is_empty() else p_id,
		"public": p_public
	})


## List all buckets that the current user has access to.
func list_buckets() -> W4APIRequest:
	return GET("/bucket")


## Empties the given bucket.
func empty_bucket(p_name: String) -> W4APIRequest:
	return POST("/bucket/%s/empty" % p_name)


## Gets the given bucket.
func get_bucket(p_name: String) -> W4APIRequest:
	return GET("/bucket/%s" % p_name)


## Updates the given bucket.
func update_bucket(p_name: String, p_public: bool) -> W4APIRequest:
	return PUT("/bucket/%s" % p_name, {
		"public": p_public
	})


## Deletes the given bucket.
func delete_bucket(p_name: String) -> W4APIRequest:
	return DELETE("/bucket/%s" % p_name)


func _get_upload_data(p_data: Variant):
	var mime := ""
	var data = null
	if typeof(p_data) == TYPE_OBJECT and p_data is FileAccess:
		var file = p_data as FileAccess
		if not file.is_open():
			return "Cannot upload closed file"
		data = file.get_buffer(file.get_length())
		var ext := file.get_path().get_extension()
		if ext in Mime.Types:
			mime = Mime.Types[ext]
	elif typeof(p_data) == TYPE_STRING:
		var file := FileAccess.open(p_data, FileAccess.READ)
		var err := file.get_open_error()
		if err != OK:
			return "Failed to open file: %s" % p_data
		data = file.get_buffer(file.get_length())
		var ext := file.get_path().get_extension()
		if ext in Mime.Types:
			mime = Mime.Types[ext]
	elif typeof(p_data) == TYPE_PACKED_BYTE_ARRAY:
		data = p_data
	else:
		return "Unknown upload data type: %d" % typeof(p_data)
	return [mime, data]


func _upload_or_update(p_update: bool, p_bucket: String, p_path: String,
		p_data: Variant, p_mime:="", p_headers:={}) -> W4APIRequest:
	var headers := p_headers.duplicate()
	var res = _get_upload_data(p_data)
	if typeof(res) != TYPE_ARRAY:
		push_error("Failed to parse upload data: %s" % str(res))
		return null
	# From user
	var mime := p_mime
	if mime.is_empty():
		# From source
		mime = res[0]
	if mime.is_empty():
		# From destination
		var ext := p_path.get_extension()
		mime = Mime.Types[ext] if ext in Mime.Types else ""
	if mime.is_empty():
		# Okay, I give up ^^
		mime = "application/octet-stream"
	headers["content-type"] = mime
	var data = res[1]
	if p_update:
		return PUT("/object/%s/%s" % [p_bucket, p_path], data, {}, headers)
	else:
		return POST("/object/%s/%s" % [p_bucket, p_path], data, {}, headers)


## Deletes the given object.
func delete_object(p_bucket: String, p_path: String) -> W4APIRequest:
	return DELETE("/object/%s/%s" % [p_bucket, p_path])


## Updates the given object.
func update_object(p_bucket: String, p_path: String, p_data, p_mime:="") -> W4APIRequest:
	return _upload_or_update(true, p_bucket, p_path, p_data, p_mime)


## Uploads a new object.
func upload_object(p_bucket: String, p_path: String, p_data, p_mime:="") -> W4APIRequest:
	return _upload_or_update(false, p_bucket, p_path, p_data, p_mime)


## Uploads a new object or updates an existing one if it already exists.
func upsert_object(p_bucket: String, p_path: String, p_data, p_mime:="") -> W4APIRequest:
	return _upload_or_update(false, p_bucket, p_path, p_data, p_mime, {"x-upsert": "true"})


## Deletes multiple objects.
func delete_objects(p_bucket: String, p_prefixes: Array[String]) -> W4APIRequest:
	return DELETE("/object/%s" % p_bucket, {
		"prefixes": p_prefixes
	})


## Gets an object as an authenticated user.
func get_object_auth(p_bucket: String, p_path: String) -> W4APIRequest:
	return GET_RAW("/object/authenticated/%s/%s" % [p_bucket, p_path])


## Gets an object as an anonymous user.
func get_object_public(p_bucket: String, p_path: String) -> W4APIRequest:
	return GET_RAW("/object/public/%s/%s" % [p_bucket, p_path])


## Gets an object.
func get_object(p_bucket: String, p_path: String) -> W4APIRequest:
	if identity.is_authenticated() or identity.is_service():
		return get_object_auth(p_bucket, p_path)
	else:
		return get_object_public(p_bucket, p_path)


## Creates a publicly sharable "signed URL" for the given object.
func create_object_url(p_bucket: String, p_path: String, p_expires_in:=0) -> W4APIRequest:
	return POST("/object/sign/%s/%s" % [p_bucket, p_path], {
		"expiresIn": p_expires_in
	} if p_expires_in else null)


func _process_object_info_result(p_result: W4APIResult) -> W4APIResult:
	if not p_result.is_error():
		var headers: Dictionary = p_result.get_data()
		var content_length: int = headers['content-length'].to_int()
		# Make values match the object metadata.
		return W4APIResult.new({
			'eTag': headers['etag'],
			'size': content_length,
			'mimetype': headers['content-type'],
			'cacheControl': headers['cache-control'],
			'lastModified': headers['last-modified'],
			'contentLength': content_length,
			'httpStatusCode': 200,
		})
	return p_result


## Gets an object's info as an authenticated user.
func get_object_info_auth(p_bucket: String, p_path: String) -> W4APIRequest:
	return HEAD("/object/authenticated/%s/%s" % [p_bucket, p_path]).then(_process_object_info_result)


## Gets an object's info as an anonymous user.
func get_object_info_public(p_bucket: String, p_path: String) -> W4APIRequest:
	return HEAD("/object/public/%s/%s" % [p_bucket, p_path]).then(_process_object_info_result)


## Gets an object's info.
func get_object_info(p_bucket: String, p_path: String) -> W4APIRequest:
	if identity.is_authenticated() or identity.is_service():
		return get_object_info_auth(p_bucket, p_path)
	else:
		return get_object_info_public(p_bucket, p_path)


## Gets an object via a "signed URL".
func get_object_from_url(p_bucket: String, p_path: String, p_token: String) -> W4APIRequest:
	return GET_RAW("/object/sign/%s/%s" % [p_bucket, p_path], {
		"token": p_token
	})


## Moves the given object.
func move_object(p_bucket: String, p_source: String, p_destination: String) -> W4APIRequest:
	return POST("/object/move", {
		"bucketId": p_bucket,
		"sourceKey": p_source,
		"destinationKey": p_destination
	})


## Lists objects.
func list_objects(p_bucket: String, p_prefix:="", p_limit:=0, p_offset:=-1,
		p_sort_col:="", p_sort_order:=SortOrder.ASC) -> W4APIRequest:
	return POST("/object/list/%s" % p_bucket, _null_stripped({
		"prefix": p_prefix,
		"limit": p_limit if p_limit else null,
		"offset": p_offset if p_offset >= 0 else null,
		"sortBy": {
			"column": p_sort_col,
			"order": "asc" if p_sort_order == SortOrder.ASC else "desc"
		} if p_sort_col.length() else null,
	}))


## Copies the given object.
func copy_object(p_bucket: String, p_source: String, p_destination: String) -> W4APIRequest:
	return POST("/object/copy", {
		"bucketId": p_bucket,
		"sourceKey": p_source,
		"destinationKey": p_destination
	})
