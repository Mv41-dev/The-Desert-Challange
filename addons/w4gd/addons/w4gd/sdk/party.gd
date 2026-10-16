## Manage W4 Cloud parties.
extends Node
class_name W4Party

const PartyEvent = W4Events.PartyEvent

## Emited when the party owner, presence or invite code is changed.
signal party_changed()
## Emited when invite list changed.
signal invites_changed()

var _party_owner := ""
## The party owner.
var party_owner : String:
	get: return _party_owner
	set(v): push_error("\"party_owner\" is a read-only property")

var _party_presence : Dictionary[String, Dictionary] = {}
## The party presence.
var party_presence : Dictionary[String, Dictionary] :
	get: return _party_presence
	set(v): push_error("\"party_presence\" is a read-only property")

var _invite_code := ""
## The party invite code.
var invite_code: String:
	get: return _invite_code
	set(v): push_error("\"invite_code\" is a read-only property")

var _invites: Array[Dictionary] = []
## The party pending invites.
var invites: Array[Dictionary]:
	get: return _invites
	set(v): push_error("\"invites\" is a read-only property")

var _client: W4SupabaseClient

func _init(p_client: W4SupabaseClient, p_events: W4Events):
	_client = p_client
	p_events.party_event_received.connect(_on_party_event)

## Update the party_from a received dictionary.
func _update_party(p_party: Dictionary):
	if !p_party.get("owner", null) or !(p_party["owner"] is String):
		push_error("Invalid or missing \"owner\" field")
		return
	if !p_party.get("presence", null) or !(p_party["presence"] is Dictionary):
		push_error("Invalid or missing \"presence\" field")
		return
	if !p_party.has("invite_code") or !(p_party["invite_code"] == null or p_party["invite_code"] is String):
		push_error("Invalid or missing \"invite_code\" field")
		return

	_party_owner = p_party["owner"]
	_party_presence.assign(p_party["presence"])
	_invite_code = p_party["invite_code"] if p_party["invite_code"] else ""

	party_changed.emit()


## Update the party_from a received dictionary.
func _update_invites(p_invites: Array):
	for invite in p_invites:
		if !invite.get("sender_id", null) or !(invite["sender_id"] is String) or !invite.get("created_at", null) or !(invite["created_at"] is String):
			push_error("Malformed invite list")
			return
	_invites.assign(p_invites)
	invites_changed.emit()

## Process a direct message.
func _on_party_event(event: PartyEvent, payload: Dictionary) -> void:
	if event == PartyEvent.CHANGED:
		if !payload.get("party", null) or !(payload["party"] is Dictionary):
			push_error("Invalid or missing \"party\" field")
			return
		_update_party(payload["party"])
	elif event == PartyEvent.PRESENCE:
		if !payload.get("user_id", null) or !(payload["user_id"] is String):
			push_error("Invalid or missing \"user_id\" field")
			return
		if !payload.get("presence", null) or !(payload["presence"] is Dictionary):
			push_error("Invalid or missing \"presence\" field")
			return
		_party_presence[payload["user_id"]] = payload["presence"]
		party_changed.emit()
	elif event == PartyEvent.INVITES:
		if !payload.has("invites") or !(payload["invites"] is Array):
			push_error("Invalid or missing \"invites\" field")
			return
		_update_invites(payload["invites"])
	else:
		push_error("Realtime message received with unknown event type: ", event)
		return


## Update the party from the database.
func update():
	# Retrieve the party.
	var party_request = _client.rest.rpc('w4public.party_get')
	var handle_party_result = func(result):
		if result.is_error():
			return result
		var d = result.as_dict()
		if !d.get("party", null) or !(d["party"] is Dictionary):
			push_error("Invalid or missing \"party\" field")
			return
		var party = d["party"]
		_update_party(party)
		return W4APIResult.new()

	# Retrieve the invites.
	var invites_request = _client.rest.rpc('w4public.party_list_invites')
	var handle_invites_result = func(result):
		if result.is_error():
			return result
		var invites = result.as_array()
		if !(invites is Array):
			push_error("Invalid or missing invites")
			return
		_update_invites(invites)
		return W4APIResult.new()

	return W4Promise.parallel([
		party_request.then(handle_party_result),
		invites_request.then(handle_invites_result)
	])

## Leave the current party.
func leave():
	var request = _client.rest.rpc('w4public.party_leave')

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)


## If the current player owns the party, give its ownership to another player in the party.
func give_ownership_to(p_player_id : String):
	var request = _client.rest.rpc('w4public.party_give_ownership_to_user', {
		user_id = p_player_id
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)


## If the current player owns the party, generate a code to invite other users to the party.
## If successful, returns the new party code.
func generate_invite_code():
	var request = _client.rest.rpc('w4public.party_generate_invite_code')

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new(result.as_dict().get('code', ''))

	return request.then(handle_result)


## Invite another player to the party
## [param p_player_id] ID of the player to invite.
func invite(p_player_id : String):
	var request = _client.rest.rpc('w4public.party_invite', {
		invited_id = p_player_id
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)


## Lists all invites addressed to the current player.
func get_all_invites():
	var request = _client.rest.rpc('w4public.party_list_invites')

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new(result.as_array())

	return request.then(handle_result)


## Reply to the invite sent by another player.
## [param p_sender_id] ID of the user who sent the invite.
## [param p_accept] If true, the current player joins the sender's user party. Discard the invite otherwise.
func reply_to_invite(p_sender_id : String, p_accept : bool):
	var request = _client.rest.rpc('w4public.party_invite_reply', {
		sender_id = p_sender_id,
		accept = p_accept,
	})

	var handle_result = func(result):
		if result.is_error():
			return result

		return W4APIResult.new()

	return request.then(handle_result)


## Join another user in their party.
## [param p_player_id] ID of the player to join.
func join_party(p_player_id : String):
	var request = _client.rest.rpc('w4public.party_join', {
		user_id = p_player_id,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)

## Join another user in their party.
## [param p_player_id] ID of the player to join.
func set_presence(p_paylod: Dictionary):
	var request = _client.rest.rpc('w4public.party_set_presence', {
		payload = p_paylod,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)
