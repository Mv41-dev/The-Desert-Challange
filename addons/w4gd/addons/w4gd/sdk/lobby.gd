extends RefCounted
class_name W4Lobby

## The lobby type.
enum Type {
	## A lobby that doesn't use W4 Cloud's dedicated server or WebRTC systems.
	LOBBY_ONLY = 0,
	## A lobby that needs a dedicated server allocated.
	DEDICATED_SERVER = 1,
	## A lobby that will use the WebRTC signalling server to create a full peer-to-peer mesh with all players.
	WEBRTC_PLAYER_MESH = 2,
	## A lobby that will use the WebRTC signalling server. All players (but the lobby creator) will connect to the lobby creator's client, who hosts the game.
	WEBRTC_PLAYER_HOST = 3,
	## A lobby that will use the WebRTC signalling server and needs a dedicated server. All players connect to the dedicated gameserver.
	WEBRTC_DEDICATED_SERVER = 4,
}

## The lobby state.
enum State {
	## A newly created lobby.
	NEW = 1,
	## The match is now in progress (players can still join and leave).
	IN_PROGRESS = 2,
	## The match is in progress, but sealed, meaning players can no longer join or leave.
	SEALED = 3,
	## The match is done and this lobby can be cleaned up.
	DONE = 4,
}

const LobbyEvent = W4Events.LobbyEvent

## Emitted when the lobby is updated.
signal updated()
## Emitted when current user has been added to the lobby.
signal joined()
## Emitted when current user has been removed from the lobby (or if the lobby is deleted).
signal left()
## Emitted when a player joins the lobby.
signal player_joined(player_id: String)
## Emitted when a player leaves the lobby.
signal player_left(player_id: String)
## Emitted when the player presence changes.
signal presence_changed(presence: Dictionary)
## Emitted when the gameserver is ready and the game can be joined.
signal gameserver_ready(address: String, port: int, secret: String)
## Emitted when a WebRTC mesh is created.
signal webrtc_multiplayer_peer_created(multiplayer_peer: WebRTCMultiplayerPeer)
## Emitted when connections to all WebRTC peers have been established.
signal webrtc_peers_ready()
## Emitted when one or more of the WebRTC peers is no longer connected, or a new peer has joined that we haven't connected to yet.
signal webrtc_peers_not_ready()

## Properties or settings for this lobby.
var props: Dictionary

## The current lobby state.
var state: State = State.NEW

var _id: String
## The lobby ID.
var id: String:
	get: return _id
	set(v): push_error("Lobby.id is a read-only property")

var _type: Type
## The lobby type.
var type: Type:
	get: return _type
	set(v): push_error("Lobby.type is a read-only property")

var _creator_id: String
## The ID of the player who created the lobby (if any).
var creator_id: String:
	get: return _creator_id
	set(v): push_error("Lobby.creator_id is a read-only property")

var _max_players: int
## The maximum number of players allowed in this lobby.
var max_players: int:
	get: return _max_players
	set(v): push_error("Lobby.max_players is a read-only property")

var _created_at: float
## When the lobby was created (in UNIX time).
var created_at: float:
	get: return _created_at
	set(v): push_error("Lobby.created_at is a read-only property")

var _updated_at: float
## When the lobby was last updated (in UNIX time).
var updated_at: float:
	get: return _updated_at
	set(v): push_error("Lobby.updated_at is a read-only property")

var _hidden: bool
## Whether or not this lobby is hidden.
var hidden: bool:
	get: return _hidden
	set(v): push_error("Lobby.hidden is a read-only property")

var _cluster: String
## The name of the cluster when using a dedicated server lobby.
var cluster: String:
	get: return _cluster
	set(v): push_error("Lobby.cluster is a read-only property")

var _gameserver_uri: String
## The name of the cluster when using a dedicated server lobby.
var gameserver_uri: String:
	get: return _gameserver_uri
	set(v): push_error("Lobby.gameserver_uri is a read-only property")

var _presence : Dictionary[StringName, Dictionary] = {}
var _secret := ""
var _webrtc_manager : W4RTCManager
var _client : W4SupabaseClient

## Creates a new lobby.
func _init(p_client: W4SupabaseClient, p_data: Dictionary, p_webrtc_ice_servers: Array):
	_id = p_data['id']
	_update_data(p_data)

	_client = p_client

	if _type == Type.WEBRTC_PLAYER_MESH or _type == Type.WEBRTC_PLAYER_HOST or _type == Type.WEBRTC_DEDICATED_SERVER:
		var mode = W4RTCManager.MultiplayerPeerMode.MESH if _type == Type.WEBRTC_PLAYER_MESH else W4RTCManager.MultiplayerPeerMode.CLIENT_SERVER
		_webrtc_manager = W4RTCManager.new(_client, _id, mode, p_webrtc_ice_servers)
		_webrtc_manager.multiplayer_peer_created.connect(_on_webrtc_manager_multiplayer_peer_created)
		_webrtc_manager.peers_ready.connect(_on_webrtc_manager_peers_ready)
		_webrtc_manager.peers_not_ready.connect(_on_webrtc_manager_peers_not_ready)
		Engine.get_main_loop().process_frame.connect(_webrtc_manager.poll)

func _update_data(p_data: Dictionary) -> void:
	var at := W4Utils.parse_timestamptz(p_data['updated_at']) if p_data.has('updated_at') else 0
	if at < _updated_at:
		return

	_updated_at = at
	_presence.assign(p_data.get('presence', _presence))
	_type = p_data['type']
	_creator_id = p_data['creator_id'] if p_data['creator_id'] != null else ''
	_max_players = p_data['max_players']
	_created_at = W4Utils.parse_timestamptz(p_data['created_at'])
	_hidden = p_data['hidden']
	_cluster = p_data['cluster'] if p_data['cluster'] != null else ''

	props = p_data['props']
	state = p_data['state']

func _on_webrtc_manager_multiplayer_peer_created(multiplayer_peer: WebRTCMultiplayerPeer) -> void:
	webrtc_multiplayer_peer_created.emit(multiplayer_peer)

func _on_webrtc_manager_peers_ready() -> void:
	webrtc_peers_ready.emit()

func _on_webrtc_manager_peers_not_ready() -> void:
	webrtc_peers_not_ready.emit()

## Returns true if the currently logged in user is the creator of this lobby.
func is_creator() -> bool:
	var identity = _client.get_identity()
	if not identity.is_authenticated():
		return false
	return identity.get_uid() == _creator_id

## Gets the current player list.
func get_players() -> Array[StringName]:
	var out : Array[StringName]
	out.assign(_presence.keys())
	return out

## Gets the current lobby presence.
func get_presence() -> Dictionary[StringName, Dictionary]:
	return _presence

func set_presence(presence: Dictionary):
	return _client.rest.rpc('w4public.lobby_set_presence', {
		lobby_id = _id,
		payload = presence,
	})

## Gets the WebRTC multiplayer peer for this lobby (if any).
func get_webrtc_multiplayer_peer() -> WebRTCMultiplayerPeer:
	if not _webrtc_manager:
		push_error("Not a WebRTC lobby")
		return null
	return _webrtc_manager.webrtc_multiplayer_peer

## Gets the WebRTC manager.
func get_webrtc_manager() -> W4RTCManager:
	if not _webrtc_manager:
		push_error("Not a WebRTC lobby")
		return null
	return _webrtc_manager

## Creates a request to save any changed properties on the lobby.
func save() -> W4APIRequest:
	var request = _client.rest.rpc('w4public.lobby_update', {
		lobby_id = _id,
		props = props,
		state = state,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)

## Creates a request to leave the lobby.
func leave() -> W4APIRequest:
	var request = _client.rest.rpc('w4public.lobby_leave', {
		lobby_id = _id,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)

## Creates a request to delete the lobby.
func delete() -> W4APIRequest:
	var request = _client.rest.rpc('w4public.lobby_delete', {
		lobby_id = _id,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		return W4APIResult.new()

	return request.then(handle_result)

func _on_lobby_updated(p_lobby) -> void:
	_update_data(p_lobby)
	updated.emit()

func _handle_event(event: LobbyEvent, payload: Dictionary) -> void:
	var lobby := payload.get("lobby", {}) as Dictionary
	var lobby_id := lobby.get("id", "") as String
	if lobby_id != _id:
		push_error("Invalid or missing lobby id: ", lobby_id, " expected: ", _id)
		return
	if event == LobbyEvent.UPDATED:
		_on_lobby_updated(payload["lobby"])
	elif event == LobbyEvent.JOINED:
		joined.emit()
	elif event == LobbyEvent.LEFT:
		left.emit()
	elif event == LobbyEvent.PLAYER_JOINED:
		var player := payload.get("player", "") as String
		if player.is_empty() or player in _presence:
			return
		_presence.assign(lobby.get("presence", _presence))
		player_joined.emit(player)
	elif event == LobbyEvent.PLAYER_LEFT:
		var player := payload.get("player", "") as String
		if player.is_empty() or not _presence.has(player):
			return
		_presence.assign(lobby.get("presence", _presence))
		player_left.emit(player)
	elif event == LobbyEvent.TICKET_CHANGED:
		var ticket := payload.get("lobby_ticket", {}) as Dictionary
		if ticket.is_empty():
			return
		# Udpate the secret
		_secret = ticket.get("secret", "")
		var uri = ticket.get("uri", "")
		if typeof(uri) == TYPE_STRING:
			_gameserver_uri = ticket.get("uri")
		if _webrtc_manager != null:
			_webrtc_manager.set_lobby_secret(_secret)
		# Trigger a signal when the gameserver is ready to join.
		if _type == Type.DEDICATED_SERVER and not _gameserver_uri.is_empty():
			var server_parts := _gameserver_uri.rsplit(':', true, 1)
			gameserver_ready.emit(server_parts[0], type_convert(server_parts[1], TYPE_INT), _secret)
	elif event == LobbyEvent.PRESENCE:
		var player := payload.get("player", "") as StringName
		if player.is_empty():
			return
		var presence := payload.get("presence", {}) as Dictionary
		_presence[player] = presence
		presence_changed.emit(_presence)
