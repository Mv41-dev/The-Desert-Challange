extends Node
class_name W4Client

@export var autoconnect := false

var client: W4SupabaseClient
var events : W4Events
var analytics: W4Analytics
var matchmaker: W4Matchmaker
var party: W4Party
var server_sdk: W4ServerSDK

# Quick aliases.
var auth: W4Auth:
	get: return client.auth as W4Auth if client != null else null
var rest: W4SupabaseRest:
	get: return client.rest if client != null else null
var pg: W4SupabaseMeta:
	get: return client.pg if client != null else null
var storage: W4SupabaseStorage:
	get: return client.storage if client != null else null
var realtime: W4SupabaseRealtime:
	get: return client.realtime if client != null else null
var identity: W4Identity:
	get: return client.identity if client != null else null

func _init(config: Dictionary = {}):
	process_mode = Node.PROCESS_MODE_ALWAYS
	W4Settings.add_project_settings()
	if config.is_empty():
		config = W4Settings.get_config()
	client = W4SupabaseClient.new(self, config["url"], config["key"], W4Settings.get_tls_options())
	client.auth = W4Auth.new(client.get_http_client(), client.get_identity())
	events = W4Events.new(client)
	analytics = W4Analytics.new(client)
	add_child(analytics)
	matchmaker = W4Matchmaker.new(client, events)
	add_child(matchmaker)
	party = W4Party.new(client, events)
	add_child(party)
	server_sdk = W4ServerSDK.new()
	server_sdk.name = 'GameServerSDK'
	add_child(server_sdk)


func _ready() -> void:
	if client != null and autoconnect:
		connect_to_realtime()

## Connects to the realtime websocket server.
## [br]
## [b]Note[/b]: This method is automatically by the [W4GD] singleton.
func connect_to_realtime() -> void:
	if client == null:
		print("Can't connect to realtime server. No client available.")
		return
	var err = client.realtime.connect_socket()
	if err != OK:
		print("Can't connect to realtime server. Error: ", err)
		return


## Disconnects from the realtime websocket server.
## [br]
## [b]Note[/b]: Some features, like the [member matchmaker], will not work when
## the realtime server is disconnected.
func disconnect_from_realtime() -> void:
	if client == null:
		return
	client.realtime.disconnect_socket()


## Returns the default port for game servers.
##
## Can be configured in the project settings ([code]w4games/servers/default_port[/code]), and
## overridden via the W4CLOUD_GAMESERVER_PORT environment variable.
##
## Usage:
## [codeblock]
## var peer := ENetMultiplayerPeer.new()
## peer.create_server(W4Client.get_server_default_port())
## [/codeblock]
static func get_server_default_port() -> int:
	var env := OS.get_environment("W4CLOUD_GAMESERVER_PORT")
	if env.is_valid_int():
		return env.to_int()
	return W4Settings.get_server_default_port()
