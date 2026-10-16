## Manages WebRTC connections for WebRTC lobbies.
extends RefCounted
class_name W4RTCManager

const RTCEvent = W4Events.RTCEvent

## The multiplayer peer that was created for this lobby.
var webrtc_multiplayer_peer: WebRTCMultiplayerPeer
## The ICE servers used to help the peers connect.
var ice_servers := []

## Used internally by [W4RTCManager] to track WebRTC sessions.
class Session extends RefCounted:
	var session_id: String
	var player_id: String
	var peer_id: int
	var peer: WebRTCPeerConnection
	var is_source: bool

	var candidate_send_queue := []
	var candidate_receive_queue := []
	var has_remote_session := false

	func _init(p_session_id: String, p_player_id: String, p_peer_id: int, p_peer: WebRTCPeerConnection, p_is_source: bool):
		session_id = p_session_id
		player_id = p_player_id
		peer_id = p_peer_id
		peer = p_peer
		is_source = p_is_source

	func send_candidate_queued(p_media: String, p_index: int, p_name: String) -> void:
		candidate_send_queue.push_back({
			media = p_media,
			index = p_index,
			name = p_name,
		})

	func receive_candidate_queued(p_media: String, p_index: int, p_name: String) -> void:
		if has_remote_session:
			peer.add_ice_candidate(p_media, p_index, p_name)
		else:
			candidate_receive_queue.push_back({
				media = p_media,
				index = p_index,
				name = p_name,
			})


enum MultiplayerPeerMode {
	MESH = 0,
	CLIENT_SERVER = 1,
}

var _lobby_id: String
var _lobby_secret: String
var _mutiplayer_peer_mode: MultiplayerPeerMode
var _my_peer_id: int
var _sessions := {}
var _sessions_by_peer := {}
var _peers_ready: bool

var _client: W4SupabaseClient

## Emitted when the WebRTC mesh is created.
signal multiplayer_peer_created(multiplayer_peer)
## Emitted when connections to all WebRTC peers have been established.
signal peers_ready()
## Emitted when one or more of the WebRTC peers is no longer connected, or a new peer has joined that we haven't connected to yet.
signal peers_not_ready()

## Creates a new WebRTC manager.
func _init(p_client: W4SupabaseClient, p_lobby_id: String, p_mutiplayer_peer_mode: MultiplayerPeerMode, p_ice_servers: Array):
	_client = p_client
	_lobby_id = p_lobby_id
	_mutiplayer_peer_mode = p_mutiplayer_peer_mode
	ice_servers = p_ice_servers

	reset()

## Resets all user sessions for a given lobby, triggering a notification to the remote player (if still connected) to renegotiate the session.
## Call this to reconnect to an in-progess or sealed WebRTC lobby.
func renegotiate() -> W4APIResult:
	return await _client.rest.rpc("w4public.webrtc_reset_lobby_sessions", {
		lobby_id = _lobby_id,
	}).async()


## Resets the WebRTC manager, closing the multiplayer peer, and clearing all sessions.
func reset() -> void:
	for session in _sessions.values():
		session.peer.session_description_created.disconnect(_on_peer_session_description_created.bind(session.peer_id))
		session.peer.ice_candidate_created.disconnect(_on_peer_ice_candidate_created.bind(session.peer_id))

	if webrtc_multiplayer_peer != null:
		webrtc_multiplayer_peer.close()
		webrtc_multiplayer_peer = null

	webrtc_multiplayer_peer = WebRTCMultiplayerPeer.new()
	_my_peer_id = 0
	_sessions.clear()
	_sessions_by_peer.clear()
	_peers_ready = false

## Gets the UUID of the player in the database for the given peer id.
func get_player_id_for_peer(peer_id: int) -> String:
	return _sessions_by_peer[peer_id].player_id

## Gets the peer id of the player for the given player UUID.
func get_peer_id_for_player(player_id: String) -> int:
	for session_id in _sessions:
		var session = _sessions[session_id]
		if session.player_id == player_id:
			return session.peer_id
	return 0

## Gets the number of peers.
func get_peer_count() -> int:
	return _sessions.size()

## Returns true if all peers are ready; otherwise, false.
func are_peers_ready() -> bool:
	return _peers_ready

## Rechecks if the peers are all ready and emits the [signal peers_ready] or [signal peers_not_ready] signal.
func poll() -> void:
	var new_peers_ready := _check_peers_ready()
	if new_peers_ready != _peers_ready:
		_peers_ready = new_peers_ready
		if _peers_ready:
			peers_ready.emit()
		else:
			peers_not_ready.emit()

func set_lobby_secret(lobby_secret: String):
	_lobby_secret = lobby_secret

func _check_peers_ready() -> bool:
	if webrtc_multiplayer_peer == null:
		return false
	if _sessions.size() == 0:
		return false

	for session_id in _sessions:
		var peer: WebRTCPeerConnection = _sessions[session_id].peer
		if peer.poll() != OK:
			return false
		if peer.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
			return false

	return true

## Refreshes the WebRTC sessions based on the sessions in the database.
func refresh_sessions() -> W4APIRequest:
	var request = _client.rest.rpc("w4public.webrtc_sessions_for_lobby", {
		lobby_id = _lobby_id,
	})

	var handle_result = func(result):
		if result.is_error():
			return result
		for record in result.sessions.as_array():
			if not record['id'] in _sessions:
				_create_session(record['id'], record)
		return W4APIResult.new()

	return request.then(handle_result)

func _handle_event(event: RTCEvent, payload: Dictionary) -> void:
	if not payload.has("lobby_id") or payload.get("lobby_id") != _lobby_id:
		push_error("Invalid message routed to RTC manager: ", event, payload)
		return

	var session : Session = _sessions.get(payload.get("session_id", ""), null)
	if event == RTCEvent.RESET:
		if session != null:
			if session.peer:
				session.peer.close()
			_sessions.erase(payload["session_id"])
		_create_session(payload["session_id"], payload)
		return
	if event == RTCEvent.SESSION:
			# We might have already added the session via a subrequest.
			if session == null:
				_create_session(payload["session_id"], payload)
			return
	if session == null:
		return

	if event == RTCEvent.OFFER or event == RTCEvent.ANSWER:
		var desc : Dictionary = payload.get('answer' if session.is_source else 'offer', {})
		if desc.is_empty():
			return
		session.peer.set_remote_description(desc['type'], desc['sdp'])
		session.has_remote_session = true
		if session.candidate_receive_queue.size() > 0:
			for c in session.candidate_receive_queue:
				session.peer.add_ice_candidate(c['media'], c['index'], c['name'])
			session.candidate_receive_queue.clear()
	elif event == RTCEvent.CANDIDATES:
		var candidates : Array = payload.get("candidates", [])
		for c in candidates:
			session.receive_candidate_queued(c['media'], c['index'], c['name'])
	else:
		push_error("Unhandled RTC message: ", RTCEvent.find_key(event))

func _create_session(session_id: String, record: Dictionary) -> void:
	var my_player_id = _client.get_identity().get_uid()
	var my_peer_id: int
	var other_player_id: String
	var other_peer_id: int
	var is_source := false

	if record['source_player_id'] == my_player_id:
		my_peer_id = record['source_peer_id']
		other_player_id = record['target_player_id']
		other_peer_id = record['target_peer_id']
		is_source = true
	else:
		my_peer_id = record['target_peer_id']
		other_player_id = record['source_player_id']
		other_peer_id = record['source_peer_id']

	if _my_peer_id != 0 and _my_peer_id != my_peer_id:
		reset()
	if _my_peer_id == 0:
		_my_peer_id = my_peer_id
		if (_mutiplayer_peer_mode == MultiplayerPeerMode.MESH):
			webrtc_multiplayer_peer.create_mesh(my_peer_id)
		else: # MultiplayerPeerMode.CLIENT_SERVER
			if (my_peer_id == 1):
				webrtc_multiplayer_peer.create_server()
			else:
				webrtc_multiplayer_peer.create_client(my_peer_id)
		_emit_multiplayer_peer_created.call_deferred()

	var peer = WebRTCPeerConnection.new()
	var servers := ice_servers
	var turnservers = record.get('turnservers', [])
	if typeof(turnservers) == TYPE_ARRAY and turnservers.size():
		var urls := []
		for s in turnservers:
			urls.append("turn:" + s)
		servers = ice_servers + [{
				urls = urls,
				credential = _lobby_secret,
				credentials = _lobby_secret,
				username = _client.get_identity().get_uid() + ':' + _lobby_id
		}]
		print(servers)
	peer.initialize({ iceServers = servers })
	peer.session_description_created.connect(_on_peer_session_description_created.bind(other_peer_id))
	peer.ice_candidate_created.connect(_on_peer_ice_candidate_created.bind(other_peer_id))
	webrtc_multiplayer_peer.add_peer(peer, other_peer_id)

	var session := Session.new(session_id, other_player_id, other_peer_id, peer, is_source)
	_sessions[session_id] = session
	_sessions_by_peer[other_peer_id] = session

	if is_source:
		peer.create_offer()

func _emit_multiplayer_peer_created():
	multiplayer_peer_created.emit(webrtc_multiplayer_peer)

func _on_peer_session_description_created(p_type: String, p_sdp: String, p_peer_id: int) -> void:
	if not _sessions_by_peer.has(p_peer_id):
		return

	var session: Session = _sessions_by_peer[p_peer_id]
	session.peer.set_local_description(p_type, p_sdp)

	var description = {
		type = p_type,
		sdp = p_sdp,
	}
	var result

	if session.is_source:
		result = await _client.rest.rpc('w4public.webrtc_create_offer', {
			session_id = session.session_id,
			offer = description,
		}).async()
	else:
		result = await _client.rest.rpc('w4public.webrtc_create_answer', {
			session_id = session.session_id,
			answer = description,
		}).async()

	if result.is_error() or not result.success.as_bool():
		print ("Unable to create offer or answer: ", str(result))

func _on_peer_ice_candidate_created(p_media: String, p_index: int, p_name: String, p_peer_id: int) -> void:
	if not _sessions_by_peer.has(p_peer_id):
		return

	var session: Session = _sessions_by_peer[p_peer_id]

	session.send_candidate_queued(p_media, p_index, p_name)
	if session.candidate_send_queue.size() == 1:
		_send_queued_candidates.call_deferred(p_peer_id)

func _send_queued_candidates(p_peer_id: int) -> void:
	if not _sessions_by_peer.has(p_peer_id):
		return

	var session: Session = _sessions_by_peer[p_peer_id]
	if session.candidate_send_queue.size() == 0:
		return

	var data := {
		session_id = session.session_id,
		candidates = session.candidate_send_queue.duplicate(),
	}
	session.candidate_send_queue.clear()

	var result = await _client.rest.rpc('w4public.webrtc_add_candidates', data).async()

	if result.is_error() or not result.success.as_bool():
		push_error("Failed to send candidates: ", data['candidates'], result)
