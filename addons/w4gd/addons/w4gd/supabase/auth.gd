## The Supabase authentication end-point at /auth/v1.
extends W4APIEndpoint
class_name W4SupabaseAuth

## The Supabase authentication admin end-point at /auth/v1/admin.
class Admin extends W4APIEndpoint:

	const DEFAULT_PER_PAGE := 50

	## Gets a list of all users.
	func get_users(page:=1, per_page:=DEFAULT_PER_PAGE) -> W4APIRequest:
		return GET("/users", {
			"page": page,
			"per_page": per_page
		})


	## Gets a user by their UUID in the database.
	func get_user(uid: StringName) -> W4APIRequest:
		return GET("/users/%s" % uid)


	## Deletes a user by their UUID in the database.
	func delete_user(uid: StringName) -> W4APIRequest:
		return DELETE("/users/%s" % uid)


	## Updates a user by their UUID in the database.
	func update_user(uid: String, data: Dictionary) -> W4APIRequest:
		return PUT("/users/%s" % uid, data)


	func create_user(email: String, password: String, confirm:=false, role:="authenticated") -> W4APIRequest:
		return POST("/users", {
			"email": email,
			"password": password,
			"role": role,
			"email_confirm": confirm
		})


## The type of user verification.
enum VerifyType { SIGNUP, RECOVERY, INVITE }

## The authentication admin end-point.
var admin : Admin

func _init(p_client: W4HTTPClient, p_endpoint: String, p_identity: W4Identity):
	super(p_client, p_endpoint, p_identity)
	admin = Admin.new(p_client, p_endpoint + "/admin", p_identity)


func _handle_login_response(result: W4APIResult) -> W4APIResult:
	if result.is_error():
		return result
	identity.set_access_token(result.access_token.as_string(), result.refresh_token.as_string())
	return result


func _login(p_type: String, p_data: Dictionary) -> W4APIRequest:
	return POST("/token?grant_type=%s" % p_type, p_data).then(_handle_login_response)


## Gets the authentication settings from Supabase.
func get_settings() -> W4APIRequest:
	return GET("/settings")


## Signup for a new user account using e-mail and password.
func signup_email(p_email: String, p_password: String) -> W4APIRequest:
	return POST("/signup", {
		"email": p_email,
		"password": p_password
	}).then(func (result: W4APIResult):
		if result.is_error() or not result.as_dict().has("access_token"):
			return result
		return _handle_login_response(result)
	)


## Login to a user account using a refresh token.
func login_refresh_token(p_token: String) -> W4APIRequest:
	return _login("refresh_token", {
		"refresh_token": p_token
	})


## Login to a user account using e-mail and password.
func login_email(p_email: String, p_password: String) -> W4APIRequest:
	return _login("password", {
		"email": p_email,
		"password": p_password
	})


## Begin SSO authentication for the given SAML domain.
func begin_sso(domain: String) -> W4APIRequest:
	return POST("/sso", {
		"domain": domain,
		"skip_http_redirect": true,
	})


## Begin SSO authentication for the given SAML provider id.
func begin_sso_id(provider_id: String) -> W4APIRequest:
	return POST("/sso", {
		"provider_id": provider_id,
		"skip_http_redirect": true,
	})


## Complete SSO authentication using the given SAML response.
func login_sso(saml_response: Dictionary) -> W4APIRequest:
	return POST("/sso/saml/acs", client.query_from_dict(saml_response), {}, {
		"Content-Type": "application/x-www-form-urlencoded"
	}).then(func (result: W4APIResult):
		if result.is_error():
			return result
		var loc : String = result.get_headers().get("location", "")
		if loc == "":
			return result
		var split := loc.split("#")
		if split.size() < 2:
			return result
		var query := split[1]
		var response = W4APIResult.new(
			client.dict_from_query(query),
			result.get_http_result()
		)
		return _handle_login_response(response)
	)


## Logout from the current authenticated user.
func logout() -> W4APIRequest:
	return POST("/logout").then(func (result: W4APIResult):
		identity.reset_access_token()
		return result
	)


## Start the password recover process for a user account registered with the given e-mail.
func recover(p_email: String) -> W4APIRequest:
	return POST("/recover", {
		"email": p_email
	})


## Send an invitation to sign-up for a new user account to the given e-mail address.
func send_invite(p_email: String) -> W4APIRequest:
	return POST("/invite", {
		"email": p_email
	})


## Verify a signup, password recovery or invite.
func verify(p_type: int, p_token: String) -> W4APIRequest:
	var type := ""
	if p_type == VerifyType.SIGNUP:
		type = "signup"
	elif p_type == VerifyType.RECOVERY:
		type = "recovery"
	elif p_type == VerifyType.INVITE:
		type = "invite"
	return POST("/verify", {
		"type": type,
		"token": p_token,
	})


## Gets the current user (if authenticated).
func get_user() -> W4APIRequest:
	return GET("/user")


## Updates the current user (if authenticated).
func update_user(p_data: Dictionary) -> W4APIRequest:
	return PUT("/user", p_data)
