@icon("uid://k35pm7rs1v3d")
extends Node
class_name W4LobbyHelper
## W4 Lobby helper node.
##
## Helper node for the of W4 Cloud matchmaking functionalities.
## [br]
## Add it to your scene or as an autoload.
## [br]
## Use it to list, join, create, and manage lobbies.
## [br]
## Connect to the relevant signals to react to lobby changes and setup the game.

## Emitted when a request to create a lobby succedes. See [method create_lobby].
signal lobby_created(lobby: W4Lobby)
## Emitted when a request to join a lobby succedes. See [method join_lobby].
signal lobby_joined(lobby: W4Lobby)
## Emitted when the currently joined lobby is updated.
signal lobby_updated(lobby: W4Lobby)
## Emitted after the leaving the currently joined lobby.
signal lobby_left(lobby: W4Lobby)
## Emitted when a new player joins the current lobby.
signal lobby_player_joined(lobby: W4Lobby, id: String)
## Emitted when a player leaves the current lobby.
signal lobby_player_left(lobby: W4Lobby, id: String)
## Emitted when a list of lobbies is retrieved after calling [method find_lobbies].
signal lobbies_found(lobbies: Array)
## Emitted when an error occurs during one of the requests.
signal request_failed(message: String)

## Emitted while in an active WebRTC lobby when a new WebRTC peer has been
## created.
## [br]
## If the [member webrtc_autostart] property is [code]true[/code] the
## [param webrtc_peer] will be set as the current [member MultiplayerAPI.multiplayer_peer].
signal lobby_webrtc_multiplayer_peer_created(webrtc_peer: WebRTCMultiplayerPeer)
## Emitted while in an active WebRTC lobby when all the WebRTC peers are ready
## (i.e. all players are connected), and the game can be started.
signal lobby_webrtc_peers_ready()
## Emitted while in an active WebRTC lobby some peers disconnects from the mesh
## (i.e. some players are no longer connected), and the condition needs to be handled.
signal lobby_webrtc_peers_not_ready()

## Emitted while in an active dedicated server lobby, when a server ticket is
## received.
## [br]
## If the [member dedicated_autostart] property is [code]true[/code] a new
## [ENetMultiplayerPeer] will be created, configured using the
## [param server_ticket] information, and assigned as the current
## [member MultiplayerAPI.multiplayer_peer].
signal gameserver_ready(server_ticket)

## The W4 client to use.
## [br]
## Normally this is automatically set to the W4GD singleton during ready, but
## can be manually set to a custom instance if needed (e.g. for editor plugins
## or to support multiple logged in users in the same game instance).
var sdk : W4Client = null

## If [code]true[/code], after joining or creating a WebRTC lobby, the produced
## [WebRTCMultiplayerPeer] will be automatically set as the active
## [MultiplayerAPI.multiplayer_peer] before emitting the
## [signal lobby_webrtc_multiplayer_peer_created] signal.
@export var webrtc_autostart := true

## If [code]true[/code], after joining or creating a dedicated server
## lobby, an [ENetMultiplayerPeer] client will be automatically created and set
## as the active [MultiplayerAPI.multiplayer_peer] before emitting the
## [signal gameserver_ready] signal.
@export var dedicated_autostart := true

var _request : W4APIRequest = null

## The currently tracked lobby, or [code]null[/code] if no lobby is tracked.
## [br]
## This is automatically set after calling [method join_lobby] or
## [method create_lobby], and automatically unset when calling
## [method leave_lobby].
var lobby : W4Lobby = null : set = _set_lobby

func _ready():
	if sdk == null:
		sdk = $/root/W4GD


func _exit_tree():
	_set_lobby(null)


## Returns [code]true[/code] if the current platform currently supports WebRTC.
## [br]
## [b]Note:[/b] The [url=https://github.com/godotengine/webrtc-native/releases/latest]
## WebRTC native plugin[/url] needs to be installed for WebRTC to be supported
## on most platforms.
func has_webrtc_support() -> bool:
	return OS.get_name() == "Web" or ClassDB.class_exists("WebRTCLibDataChannel")


## Requests to create a new lobby. Emits the [signal lobby_created] signal
## on succes, the [signal request_failed] signal on failure.
## [br]
## See [method W4Matchmaker.create_lobby].
func create_lobby(type: W4Lobby.Type = W4Lobby.Type.LOBBY_ONLY, opts:={}):
	if _request != null:
		cancel()
	var handle_result := func(result: W4APIResult):
		_request = null
		if result.is_error():
			request_failed.emit("Error creating lobby " + result.as_error().message)
			return
		var lobby : W4Lobby = result.get_data()
		_set_lobby(lobby)
		lobby_created.emit(lobby)
	_request = sdk.matchmaker.create_lobby(type, opts).then(handle_result)
	_request.async()


## Requests a list of lobbies matching the given [param query]. Emits the
## [signal lobbies_found] signal on succes, the [signal request_failed] signal
## on failure.
## [br]
## See [method W4Matchmaker.find_lobbies].
func find_lobbies(query:={}):
	var handle_result := func(result: W4APIResult):
		_request = null
		if result.is_error():
			request_failed.emit("Error listing lobby " + result.as_error().message)
			return
		var lobbies : Array = result.as_array()
		lobbies_found.emit(lobbies)
	_request = sdk.matchmaker.find_lobbies(query).then(handle_result)
	_request.async()


## Requests to join a lobby with the given [param code]. Emits the
## [signal lobby_joined] signal on success, the [signal request_failed] signal
## on failure.
func join_lobby(code: String):
	if _request != null:
		cancel()
	var handle_result := func(result: W4APIResult):
		_request = null
		if result.is_error():
			request_failed.emit("Error joining lobby " + result.as_error().message)
			return
		var lobby : W4Lobby = result.get_data()
		_set_lobby(lobby)
		lobby_joined.emit(lobby)
	_request = sdk.matchmaker.join_lobby(code).then(handle_result)
	_request.async()


## Requests to update the state of the current lobby. Emits the
## [signal request_failed] signal on failure.
func set_lobby_state(state: W4Lobby.State):
	if lobby == null:
		request_failed.emit("Not in a lobby")
		return
	if _request != null:
		cancel()
	lobby.state = state
	var handle_result := func (result: W4APIResult):
		_request = null
		if result.is_error():
			request_failed.emit("Error setting lobby state " + result.as_error().message)
			return
	_request = lobby.save().then(handle_result)
	_request.async()


## Requests to leave the current lobby. Emits the [signal lobby_left] signal on
## succes, the [signal request_failed] signal on failure.
func leave_lobby():
	if lobby == null:
		request_failed.emit("Not in a lobby")
		return
	if _request != null:
		cancel()
	var handle_result := func(result: W4APIResult):
		_request = null
		if result.is_error():
			request_failed.emit("Error leaving lobby " + result.as_error().message)
			return
		lobby_left.emit(lobby)
		_set_lobby(null)
	_request = lobby.leave().then(handle_result)
	_request.async()


## Cancel any currently pending request.
func cancel():
	if _request == null or _request.result == null:
		return
	_request.result.cancel()
	_request = null


func _gameserver_ready(address: String, port: int, secret: String):
	# Enable Godot multiplayer authentication system using the given secret.
	sdk.server_sdk.start_client(sdk.identity.get_uid(), secret)
	if dedicated_autostart:
		# Start ENet client.
		var peer := ENetMultiplayerPeer.new()
		peer.create_client(address, port)
		multiplayer.multiplayer_peer = peer
	gameserver_ready.emit(address, port, secret)


func _set_lobby(new_lobby: W4Lobby):
	if lobby == new_lobby:
		return
	if lobby != null:
		lobby.updated.disconnect(_lobby_changed)
		lobby.left.disconnect(_lobby_left)
		lobby.player_joined.disconnect(_player_joined)
		lobby.player_left.disconnect(_player_left)
		lobby.webrtc_peers_ready.disconnect(_lobby_webrtc_peers_ready)
		lobby.webrtc_peers_not_ready.disconnect(_lobby_webrtc_peers_not_ready)
		lobby.webrtc_multiplayer_peer_created.disconnect(_lobby_webrtc_multiplayer_peer_created)
		lobby.gameserver_ready.disconnect(_gameserver_ready)
		if lobby.is_creator():
			lobby.delete().async()
		elif lobby.state < W4Lobby.State.SEALED:
			lobby.leave().async()
	lobby = new_lobby
	if lobby:
		lobby.updated.connect(_lobby_changed)
		lobby.left.connect(_lobby_left)
		lobby.player_joined.connect(_player_joined)
		lobby.player_left.connect(_player_left)
		lobby.webrtc_peers_ready.connect(_lobby_webrtc_peers_ready)
		lobby.webrtc_peers_not_ready.connect(_lobby_webrtc_peers_not_ready)
		lobby.webrtc_multiplayer_peer_created.connect(_lobby_webrtc_multiplayer_peer_created)
		lobby.gameserver_ready.connect(_gameserver_ready)

func _lobby_changed():
	lobby_updated.emit(lobby)


func _lobby_left():
	lobby_left.emit(lobby)
	_set_lobby(null)


func _player_joined(id: String):
	lobby_player_joined.emit(lobby, id)


func _player_left(id: String):
	lobby_player_left.emit(lobby, id)


func _lobby_webrtc_multiplayer_peer_created(peer: WebRTCMultiplayerPeer):
	if webrtc_autostart:
		multiplayer.auth_callback = Callable()
		multiplayer.multiplayer_peer = peer
	lobby_webrtc_multiplayer_peer_created.emit(peer)


func _lobby_webrtc_peers_ready():
	lobby_webrtc_peers_ready.emit()

func _lobby_webrtc_peers_not_ready():
	lobby_webrtc_peers_not_ready.emit()
