## Interacts with the W4 Cloud matchmaker component.
extends Node
class_name W4Matchmaker

enum Channel {MATCHMAKER, USER}

## Represents the players place in the matchmaking queue.
class MatchmakerTicket extends RefCounted:
	## The ticket ID.
	var id: String
	## The ID of the lobby (if any) that was created by the matchmaker for this ticket.
	var lobby_id: String

	## Emitted when a lobby is created for this ticket.
	signal matched (lobby_id)

	## Creates a matchmaker ticket.
	func _init(p_id: String):
		id = p_id

	func _match(p_lobby: String) -> void:
		lobby_id = p_lobby
		matched.emit(lobby_id)

## The default WebRTC ICE servers, if none are provided.
const DEFAULT_WEBRTC_ICE_SERVERS := [
	{
		"urls": [
			"stun:stun.l.google.com:19302",
			"stun:stun1.l.google.com:19302",
			"stun:stun2.l.google.com:19302",
			"stun:stun3.l.google.com:19302",
			"stun:stun4.l.google.com:19302",
		],
	},
]

var _client: W4SupabaseClient
var _webrtc_ice_servers: Array = DEFAULT_WEBRTC_ICE_SERVERS
var _matchmaker_tickets := {}
var _matchmaker_channel : W4SupabaseRealtime.Subscription
var _lobbies : Dictionary[String, W4Lobby]
var _last_uid := ""

func _init(p_client: W4SupabaseClient, p_events: W4Events):
	_client = p_client
	_client.identity.identity_changed.connect(_subscribe_to_matchmaker)
	_client.realtime.connection_succeded.connect(_subscribe_to_matchmaker)
	_client.realtime.connection_closed.connect(_subscribe_to_matchmaker)
	p_events.lobby_event_received.connect(_lobby_event)
	p_events.rtc_event_received.connect(_rtc_event)
	p_events.matchmaker_event_received.connect(_ticket_event)
	_subscribe_to_matchmaker()


## Sets the list of WebRTC ICE servers.
func set_webrtc_ice_servers(p_ice_servers: Array) -> void:
	_webrtc_ice_servers = p_ice_servers


## Gets a list of valid dedicated server cluster names.
func get_cluster_list() -> W4APIRequest:
	return _client.rest.rpc_const('w4public.cluster_get_all')


## Creates a request to create a new lobby. A [W4Lobby] will be returned as the data.
##
## [param p_opts] can contain the following keys:
## - [code]props[/code]: A [Dictionary] of lobby properties to be used as needed by your game.
## - [code]max_players[/code]: The maximum number of players allowed in the lobby (the default is [code]2[/code]).
## - [code]initial_players[/code]: An [Array] of player UUIDs to add to automatically join to the lobby.
## - [code]cluster[/code]: The name of the cluster to allocate the dedicated server when using a dedicated server lobby.
## - [code]hidden[/code]: If [code]true[/code], the lobby will not be publicly listable.
func create_lobby(p_type: W4Lobby.Type = W4Lobby.Type.LOBBY_ONLY, p_opts := {}, p_subscribe: bool = true) -> W4APIRequest:
	var props = p_opts.get('props', {})
	var max_players = p_opts.get('max_players', 2)
	var prealloc_players = p_opts.get('initial_players', [])
	var cluster = p_opts.get('cluster', null) if p_type == W4Lobby.Type.DEDICATED_SERVER else null
	var hidden = p_opts.get('hidden', false)

	if p_type == W4Lobby.Type.WEBRTC_DEDICATED_SERVER:
		push_error("'Lobbype.WEBRTC_DEDICATED_SERVER' is not supported in this version of the SDK")
		assert(false)
		return null

	if p_opts.has('fleet_labels') and p_opts['fleet_labels'] is Dictionary:
		props['gameServerSelectors'] = [{
			matchLabels = p_opts['fleet_labels']
		}]

	var request = _client.rest.rpc('w4public.lobby_create', {
		type = p_type,
		props = props,
		max_players = max_players,
		prealloc_players = prealloc_players,
		cluster = cluster,
		hidden = hidden,
	})

	var handle_result = func(result: W4APIResult):
		if result.is_error():
			return result
		return W4APIResult.new(_track_lobby(result.lobby.as_dict()))

	return request.then(handle_result)


## Creates a request to join a lobby. A [W4Lobby] will be returned as the data.
func join_lobby(p_lobby_id: String, p_subscribe: bool = true) -> W4APIRequest:
	var request = _client.rest.rpc('w4public.lobby_join', {
		lobby_id = p_lobby_id
	})

	var handle_result = func(result: W4APIResult):
		if result.is_error():
			return result
		return W4APIResult.new(_track_lobby(result.lobby.as_dict()))

	return request.then(handle_result)


## Creates a request to get a lobby. A [W4Lobby] will be returned as the data.
func get_lobby(p_lobby_id: String, p_subscribe: bool = true) -> W4APIRequest:
	var request = _client.rest.rpc('w4public.lobby_by_id', {
		lobby_id = p_lobby_id,
	})
	var handle_result := func(result):
		if result.is_error():
			return result
		return W4APIResult.new(_track_lobby(result.as_dict()))
	return request.then(handle_result)


## Creates a request to find lobbies that the current player has access to.
##
## This can be useful after restarting the game to see if we can reconnect to an existing match.
##
## [param p_query] is a [Dictionary] that takes the following keys:
## - [code]only_my_lobbies[/code] (bool): If set to true, this will only list lobbies that the current user has joined.
## - [code]include_player_count[/code] (bool): If set to true, this will include [code]player_count[/code] in the result.
## - [code]constraints[/code] ([Dictionary]): A Dictionary of constraints that lobbies must match.
##
## Returns an array of [Dictionary]'s with the following keys:
## - [code]id[/code]
## - [code]type[/code]
## - [code]state[/code]
## - [code]creator_id[/code]
## - [code]props[/code]
## - [code]cluster[/code]
## - [code]created_at[/code]
##
## Usage:
## [codeblock]
## var result = await W4GD.matchmaker.find_lobbies({
##     # Includes a `player_count` for each lobby in the result.
##     include_player_count = true,
##     # Filters to only include lobbies the current user is a member of (as opposed to all lobbies they have access to).
##     only_my_lobbies = true,
##     # Arbitrary constraints on the lobby's columns and properties.
##     constraints = {
##         'type': W4Lobby.Type.DEDICATED_SERVER,
##         'state': [W4GD.matchmaker.W4Lobby.State.NEW, W4GD.matchmaker.W4Lobby.State.IN_PROGRESS],
##         'player_count': {
##             op = '<',
##             value = 5,
##         },
##         # This is a top-level element inside the JSON of the 'props' column.
##         'props.game-mode': 'battle-royale',
##     },
## }).async()
## [/codeblock]
func find_lobbies(p_query: Dictionary = {}) -> W4APIRequest:
	if p_query.has('constraints'):
		var full_constraints := {}
		for k in p_query['constraints']:
			var v = p_query['constraints'][k]
			if v is Dictionary:
				full_constraints[k] = v
			elif v is Array:
				full_constraints[k] = {
					op = 'IN',
					value = v,
				}
			else:
				full_constraints[k] = {
					value = v,
				}
		p_query['constraints'] = full_constraints

	var request = _client.rest.rpc('w4public.lobby_find', {query = p_query})

	var handle_result = func(result):
		if result.is_error():
			return result
		# Make the result into an Array of lobbies.
		return W4APIResult.new(result.as_dict().get('lobbies', []))

	return request.then(handle_result)


## Creates a request to join the matchmaker queue.
##
## A [W4MatchmakerTicket] will be returned as the data.
func join_matchmaker_queue(p_props: Dictionary = {}, p_auto_leave: bool = true) -> W4APIRequest:
	var request = _client.rest.rpc('w4public.matchmaker_join', {
		props = p_props,
		auto_leave = p_auto_leave,
	})
	var handle_result := func (p_result: W4APIResult) -> W4APIResult:
		if p_result.is_error():
			return p_result
		var ticket = _get_or_create_matchmaker_ticket(p_result.ticket_id.as_string())
		# If the ticket already has a lobby, then emit the matched signal after the calling
		# code has had an opportunity to subscribe to it.
		if ticket.lobby_id != "":
			ticket._match.call_deferred(ticket.lobby_id)
		return W4APIResult.new(ticket)
	return request.then(handle_result)


## Creates a request to leave the matchmaker queue.
func leave_matchmaker_queue(p_matchmaker_ticket: MatchmakerTicket) -> W4APIRequest:
	var request = _client.rest.rpc('w4public.matchmaker_leave', {
		ticket_id = p_matchmaker_ticket.id,
	})
	return request


func _subscribe_to_matchmaker() -> void:
	if not _client.realtime.is_socket_connected():
		_matchmaker_channel = null
		return
	var uid := _client.get_identity().get_uid()
	if _last_uid == uid:
		return # Just a refresh
	if _matchmaker_channel != null:
		await _matchmaker_channel.unsubscribe() # Identity changed, need to re-subscribe.
		_matchmaker_channel = null
	if uid == "":
		return # Not logged in
	_matchmaker_channel = _client.realtime.channel('matchmaker', {
		presence = { key = uid },
		private = true
	})
	if await _matchmaker_channel.subscribe() != OK:
		push_error("Failed to subscribe to matchmaker channel: ", _matchmaker_channel.error)
	_matchmaker_channel.track({ status = 'connected' })


func _get_or_create_matchmaker_ticket(p_ticket_id: String, p_lobby_id = null) -> MatchmakerTicket:
	if not _matchmaker_tickets.has(p_ticket_id):
		_matchmaker_tickets[p_ticket_id] = MatchmakerTicket.new(p_ticket_id)
	return _matchmaker_tickets[p_ticket_id]


func _lobby_event(lobby_id: StringName, event: W4Events.LobbyEvent, payload: Dictionary) -> void:
	if event == W4Events.LobbyEvent.LEFT and not _lobbies.has(lobby_id):
		return # No need to track it
	var lobby := _track_lobby(payload.get("lobby", {}))
	lobby._handle_event(event, payload)
	if event == W4Events.LobbyEvent.LEFT:
		_lobbies.erase(lobby_id)


func _rtc_event(lobby_id: StringName, event: W4Events.RTCEvent, payload: Dictionary) -> void:
	var lobby : W4Lobby = _lobbies.get(lobby_id)
	if lobby == null:
		push_error("Received webrc message for an untracked lobby: ", payload)
		return
	lobby.get_webrtc_manager()._handle_event(event, payload)


func _ticket_event(ticket_id: StringName, event: W4Events.MatchmakerEvent, payload: Dictionary) -> void:
	if event == W4Events.MatchmakerEvent.MATCHED:
		var lobby_dict : Dictionary = payload.get('lobby', {})
		var ticket := _get_or_create_matchmaker_ticket(ticket_id)
		ticket._match(lobby_dict.get("id", ""))
	elif event == W4Events.MatchmakerEvent.DELETED:
		_matchmaker_tickets.erase(ticket_id)


func _track_lobby(data: Dictionary) -> W4Lobby:
	var id : String = data.get("id", "")
	var lobby : W4Lobby = _lobbies.get(id)
	if lobby == null:
		lobby = W4Lobby.new(_client, data, _webrtc_ice_servers)
		_lobbies[id] = lobby
	else:
		lobby._on_lobby_updated(data)
	return lobby
