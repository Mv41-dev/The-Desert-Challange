extends RefCounted
class_name W4Events

enum LobbyEvent {CREATED, UPDATED, JOINED, LEFT, PLAYER_JOINED, PLAYER_LEFT, PRESENCE, TICKET_CHANGED}
enum RTCEvent {SESSION, RESET, ANSWER, OFFER, CANDIDATES}
enum PartyEvent {CHANGED, PRESENCE, INVITES}
enum MatchmakerEvent {MATCHED, DELETED}

const LOBBY_EVENTS : Dictionary[String, LobbyEvent] = {
	"lobby_created": LobbyEvent.CREATED,
	"lobby_updated": LobbyEvent.UPDATED,
	"lobby_joined": LobbyEvent.JOINED,
	"lobby_left": LobbyEvent.LEFT,
	"lobby_player_joined": LobbyEvent.PLAYER_JOINED,
	"lobby_player_left": LobbyEvent.PLAYER_LEFT,
	"lobby_presence": LobbyEvent.PRESENCE,
	"lobby_ticket_changed": LobbyEvent.TICKET_CHANGED,
}

const RTC_EVENTS : Dictionary[String, RTCEvent] = {
	"webrtc_session": RTCEvent.SESSION,
	"webrtc_reset": RTCEvent.RESET,
	"webrtc_offer": RTCEvent.OFFER,
	"webrtc_answer": RTCEvent.ANSWER,
	"webrtc_candidates": RTCEvent.CANDIDATES,
}

const PARTY_EVENTS : Dictionary[String, PartyEvent] = {
	"party_changed": PartyEvent.CHANGED,
	"party_presence": PartyEvent.PRESENCE,
	"party_invites": PartyEvent.INVITES,
}

const MATCHMAKER_EVENTS : Dictionary[String, MatchmakerEvent] = {
	"matchmaker_matched": MatchmakerEvent.MATCHED,
	"matchmaker_removed": MatchmakerEvent.DELETED
}

signal matchmaker_event_received(ticket_id: StringName, event: MatchmakerEvent, payload: Dictionary)
signal lobby_event_received(lobby_id: StringName, event: LobbyEvent, payload: Dictionary)
signal rtc_event_received(lobby_id: StringName, event: RTCEvent, payload: Dictionary)
signal party_event_received(event: PartyEvent, payload: Dictionary)
signal event_received(event: String, payload: Dictionary)

var _client : W4SupabaseClient
var _channel : W4SupabaseRealtime.Subscription
var _last_uid : StringName = ""
var _connected := false

func _init(client: W4SupabaseClient) -> void:
	_client = client
	_client.realtime.connection_succeded.connect(_identity_changed)
	_client.realtime.connection_closed.connect(_identity_changed)
	_client.identity.identity_changed.connect(_identity_changed)

func _identity_changed():
	if not _client.realtime.is_socket_connected():
		_channel = null
		return
	var uid := _client.get_identity().get_uid()
	if _last_uid == uid:
		return # Just a refresh
	_last_uid = uid
	if _channel != null:
		await _channel.unsubscribe() # Identity changed, need to re-subscribe.
		_channel = null
	if uid == "":
		return # Not logged in
	_channel = _client.realtime.channel("user#"+uid, { private = true })
	_channel.received_broadcast.connect(_on_message)
	if await _channel.subscribe() != OK:
		push_error("Failed to subscribe to user channel: ", _channel.error)

func _on_message(p_data):
	var event : String = str(p_data.get("event", ""))
	var payload : Dictionary = p_data.get("payload", "")
	if event in LOBBY_EVENTS:
		var lobby := payload.get("lobby", {}) as Dictionary
		var lobby_id := lobby.get("id", "") as String
		if lobby_id.is_empty():
			push_error("Invalid lobby event: ", p_data)
		else:
			lobby_event_received.emit(lobby_id, LOBBY_EVENTS[event], payload)
	elif event in RTC_EVENTS:
		var lobby_id := payload.get("lobby_id", "") as String
		if lobby_id.is_empty():
			push_error("Invalid WebRTC event: ", p_data)
		else:
			rtc_event_received.emit(lobby_id, RTC_EVENTS[event], payload)
	elif event in PARTY_EVENTS:
		party_event_received.emit(PARTY_EVENTS[event], payload)
	elif event in MATCHMAKER_EVENTS:
		var ticket_id : StringName = payload.get("ticket", {}).get("id", StringName())
		if ticket_id.is_empty():
			push_error("Invalid Matchmaker event: ", p_data)
		else:
			matchmaker_event_received.emit(ticket_id, MATCHMAKER_EVENTS[event], payload)
	event_received.emit(event, payload)
