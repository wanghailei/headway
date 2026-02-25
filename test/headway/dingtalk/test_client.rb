# Tests for Headway::DingTalk::Client. Verifies token fetching, caching,
# refresh, header injection, and error handling using Faraday test stubs.

require "test_helper"
require "json"

class TestDingTalkClient < Minitest::Test
	def auth_response( token: "test-token", expire_in: 7200 )
		JSON.generate( { accessToken: token, expireIn: expire_in } )
	end

	def build_stubs( &block )
		Faraday::Adapter::Test::Stubs.new( &block )
	end

	def build_connection( stubs )
		Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end
	end

	def test_fetches_token_and_sends_header
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/todo/users/u1/tasks" ) do | env |
				assert_equal "test-token", env.request_headers["x-acs-dingtalk-access-token"]
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( { items: [] } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		result = client.get( "/v1.0/todo/users/u1/tasks", connection: conn )
		assert_equal( { "items" => [] }, result )
		stubs.verify_stubbed_calls
	end

	def test_caches_token_across_requests
		auth_calls = 0
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				auth_calls += 1
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/first" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
			stub.get( "/v1.0/second" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.get( "/v1.0/first", connection: conn )
		client.get( "/v1.0/second", connection: conn )
		assert_equal 1, auth_calls
	end

	def test_refreshes_expired_token
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/data" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		# Force token to be expired
		client.instance_variable_set( :@token, "old" )
		client.instance_variable_set( :@token_expires_at, Time.now - 1 )
		client.get( "/v1.0/data", connection: conn )
		assert_equal "test-token", client.instance_variable_get( :@token )
	end

	def test_post_sends_body
		last_body = nil
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/v1.0/doc/update" ) do | env |
				last_body = JSON.parse( env.body )
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.post( "/v1.0/doc/update", body: { content: "hello" }, connection: conn )
		assert_equal "hello", last_body["content"]
	end

	def test_legacy_post_uses_oapi_host_and_query_token
		last_env = nil
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/topapi/report/list" ) do | env |
				last_env = env
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( { result: {} } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.legacy_post( "/topapi/report/list", body: { cursor: 0 }, connection: conn )
		assert_includes last_env.url.to_s, "access_token=test-token"
	end

	def test_raises_auth_error_on_failed_auth
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 401, { "Content-Type" => "application/json" }, JSON.generate( { message: "invalid" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "bad", app_secret: "bad" )
		assert_raises( Headway::DingTalk::Client::AuthError ) do
			client.get( "/v1.0/anything", connection: conn )
		end
	end

	def test_raises_auth_error_when_access_token_missing_from_response
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		error = assert_raises( Headway::DingTalk::Client::AuthError ) do
			client.get( "/v1.0/anything", connection: conn )
		end
		assert_includes error.message, "no accessToken"
	end

	def test_raises_api_error_on_failed_request
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/bad" ) do | env |
				[ 500, { "Content-Type" => "application/json" }, JSON.generate( { message: "server error" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		assert_raises( Headway::DingTalk::Client::APIError ) do
			client.get( "/v1.0/bad", connection: conn )
		end
	end

	def test_raises_api_error_on_non_json_error_response
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/bad" ) do | env |
				[ 503, { "Content-Type" => "text/plain" }, "Service Unavailable" ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		error = assert_raises( Headway::DingTalk::Client::APIError ) do
			client.get( "/v1.0/bad", connection: conn )
		end
		assert_includes error.message, "503"
		assert_includes error.message, "Service Unavailable"
	end

	def test_legacy_post_raises_on_errcode
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/topapi/report/list" ) do | env |
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { errcode: 88, errmsg: "missing permission" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		error = assert_raises( Headway::DingTalk::Client::APIError ) do
			client.legacy_post( "/topapi/report/list", body: {}, connection: conn )
		end
		assert_includes error.message, "88"
		assert_includes error.message, "missing permission"
	end

	def test_legacy_post_passes_on_errcode_zero
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/topapi/report/list" ) do | env |
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { errcode: 0, errmsg: "ok", result: { data_list: [] } } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		result = client.legacy_post( "/topapi/report/list", body: {}, connection: conn )
		assert_equal 0, result["errcode"]
	end

	def test_raises_on_missing_app_key
		assert_raises( ArgumentError ) do
			Headway::DingTalk::Client.new( app_key: nil, app_secret: "secret" )
		end
	end

	def test_raises_on_missing_app_secret
		assert_raises( ArgumentError ) do
			Headway::DingTalk::Client.new( app_key: "key", app_secret: nil )
		end
	end
end
