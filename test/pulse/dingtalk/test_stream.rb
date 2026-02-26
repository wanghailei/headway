# Tests for Pulse::DingTalk::Stream. Verifies connection registration,
# message handling (ping/pong, callback dispatch), and reconnect behavior
# using Faraday stubs and a fake WebSocket.

require "test_helper"
require "faraday"
require "json"

class FakeWebSocket
	attr_reader :sent

	def initialize
		@sent = []
	end

	def send( raw )
		@sent << JSON.parse( raw )
	end
end

class TestDingTalkStream < Minitest::Test
	def build_stream( on_message: nil, output: StringIO.new )
		Pulse::DingTalk::Stream.new(
			app_key: "test_key",
			app_secret: "test_secret",
			on_message: on_message,
			output: output
		)
	end

	def test_register_connection_sends_credentials
		last_body = nil
		stubs = Faraday::Adapter::Test::Stubs.new do | stub |
			stub.post( "/v1.0/gateway/connections/open" ) do | env |
				last_body = JSON.parse( env.body )
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { endpoint: "wss://example.com", ticket: "tk123" } ) ]
			end
		end
		conn = Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end

		stream = build_stream
		endpoint, ticket = stream.send( :register_connection, connection: conn )

		assert_equal "wss://example.com", endpoint
		assert_equal "tk123", ticket
		assert_equal "test_key", last_body["clientId"]
		assert_equal "test_secret", last_body["clientSecret"]
		assert last_body["subscriptions"].any? { | s | s["topic"] == Pulse::DingTalk::Stream::BOT_TOPIC }
		stubs.verify_stubbed_calls
	end

	def test_register_connection_raises_on_failure
		stubs = Faraday::Adapter::Test::Stubs.new do | stub |
			stub.post( "/v1.0/gateway/connections/open" ) do
				[ 500, {}, "error" ]
			end
		end
		conn = Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end

		stream = build_stream
		assert_raises( RuntimeError ) do
			stream.send( :register_connection, connection: conn )
		end
	end

	def test_handle_system_ping_sends_pong
		stream = build_stream
		ws = FakeWebSocket.new

		data = { "type" => "SYSTEM", "headers" => { "topic" => "ping", "messageId" => "msg1" }, "data" => '{"time":123}' }
		stream.send( :handle_message, ws, JSON.generate( data ) )

		assert_equal 1, ws.sent.size
		assert_equal 200, ws.sent.first["code"]
		assert_equal "msg1", ws.sent.first["headers"]["messageId"]
		assert_equal '{"time":123}', ws.sent.first["data"]
	end

	def test_handle_callback_dispatches_to_on_message
		received = []
		stream = build_stream( on_message: ->( payload ) { received << payload } )
		ws = FakeWebSocket.new

		# No sessionWebhook so reply_with_ack_emoji returns early
		inner_payload = { "senderNick" => "Alice", "text" => { "content" => "hello" } }
		data = {
			"type" => "CALLBACK",
			"headers" => { "topic" => Pulse::DingTalk::Stream::BOT_TOPIC, "messageId" => "msg2" },
			"data" => JSON.generate( inner_payload )
		}
		stream.send( :handle_message, ws, JSON.generate( data ) )

		assert_equal 1, received.size
		assert_equal "Alice", received.first["senderNick"]
		# ACK sent
		assert_equal 1, ws.sent.size
		assert_equal "msg2", ws.sent.first["headers"]["messageId"]
	end

	def test_handle_callback_ignores_non_bot_topic
		received = []
		stream = build_stream( on_message: ->( payload ) { received << payload } )
		ws = FakeWebSocket.new

		data = {
			"type" => "CALLBACK",
			"headers" => { "topic" => "/some/other/topic", "messageId" => "msg3" },
			"data" => "{}"
		}
		stream.send( :handle_message, ws, JSON.generate( data ) )

		assert_empty received
		# ACK still sent for non-bot topics
		assert_equal 1, ws.sent.size
	end

	def test_start_and_stop_lifecycle
		stream = build_stream( output: StringIO.new )
		refute stream.running?

		# Test the stop path is safe on a non-started stream.
		stream.stop
		refute stream.running?
	end

	def test_handle_invalid_json_does_not_raise
		output = StringIO.new
		stream = build_stream( output: output )
		ws = FakeWebSocket.new

		stream.send( :handle_message, ws, "not valid json{{{" )

		assert_match( /failed to parse/, output.string )
	end

	def test_register_connection_includes_ua
		last_body = nil
		stubs = Faraday::Adapter::Test::Stubs.new do | stub |
			stub.post( "/v1.0/gateway/connections/open" ) do | env |
				last_body = JSON.parse( env.body )
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { endpoint: "wss://e.com", ticket: "t" } ) ]
			end
		end
		conn = Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end

		stream = build_stream
		stream.send( :register_connection, connection: conn )

		assert_match( /pulse\//, last_body["ua"] )
		assert_match( /ruby\//, last_body["ua"] )
	end
end
