# Tests for Headway::ResponsesClient. Verifies prompt sending, response
# parsing, instructions handling, and error propagation using Faraday's
# test adapter to stub HTTP interactions.

require "test_helper"
require "json"

class TestResponsesClient < Minitest::Test
	def build_stubs( &block )
		stubs = Faraday::Adapter::Test::Stubs.new
		stubs.post( "responses", &block )
		stubs
	end

	def build_connection( stubs )
		Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end
	end

	def ok_response( text )
		JSON.generate( {
			output: [
				{
					type: "message",
					role: "assistant",
					content: [
						{ type: "output_text", text: text, annotations: [] }
					]
				}
			]
		} )
	end

	def test_sends_prompt_and_returns_text
		stubs = build_stubs do | _env |
			[ 200, { "Content-Type" => "application/json" }, ok_response( "AI response here" ) ]
		end
		conn = build_connection( stubs )

		client = Headway::ResponsesClient.new(
			base_url: "http://localhost",
			api_key: "test-token",
			model: "gpt-4o"
		)
		result = client.chat( "Summarize this: hello world", connection: conn )
		assert_equal "AI response here", result
		stubs.verify_stubbed_calls
	end

	def test_sends_instructions_when_system_given
		last_request = nil
		stubs = build_stubs do | env |
			last_request = JSON.parse( env.body )
			[ 200, { "Content-Type" => "application/json" }, ok_response( "ok" ) ]
		end
		conn = build_connection( stubs )

		client = Headway::ResponsesClient.new(
			base_url: "http://localhost",
			api_key: "test-token",
			model: "gpt-4o"
		)
		client.chat( "user prompt", system: "system prompt", connection: conn )
		assert_equal "system prompt", last_request["instructions"]
		assert_equal "user prompt", last_request["input"]
		stubs.verify_stubbed_calls
	end

	def test_omits_instructions_when_no_system
		last_request = nil
		stubs = build_stubs do | env |
			last_request = JSON.parse( env.body )
			[ 200, { "Content-Type" => "application/json" }, ok_response( "ok" ) ]
		end
		conn = build_connection( stubs )

		client = Headway::ResponsesClient.new(
			base_url: "http://localhost",
			api_key: "test-token",
			model: "gpt-4o"
		)
		client.chat( "just a prompt", connection: conn )
		refute last_request.key?( "instructions" )
		stubs.verify_stubbed_calls
	end

	def test_sends_model_in_request
		last_request = nil
		stubs = build_stubs do | env |
			last_request = JSON.parse( env.body )
			[ 200, { "Content-Type" => "application/json" }, ok_response( "ok" ) ]
		end
		conn = build_connection( stubs )

		client = Headway::ResponsesClient.new(
			base_url: "http://localhost",
			api_key: "test-token",
			model: "gpt-4o"
		)
		client.chat( "test", connection: conn )
		assert_equal "gpt-4o", last_request["model"]
		stubs.verify_stubbed_calls
	end

	def test_raises_on_api_error
		stubs = build_stubs do | _env |
			[
				429,
				{ "Content-Type" => "application/json" },
				JSON.generate( { error: { message: "rate limited" } } )
			]
		end
		conn = build_connection( stubs )

		client = Headway::ResponsesClient.new(
			base_url: "http://localhost",
			api_key: "test-token",
			model: "gpt-4o"
		)
		error = assert_raises( Headway::ResponsesClient::APIError ) do
			client.chat( "test", connection: conn )
		end
		assert_includes error.message, "429"
		assert_includes error.message, "rate limited"
	end

	def test_raises_on_missing_api_key
		assert_raises ArgumentError do
			Headway::ResponsesClient.new(
				base_url: "http://localhost",
				api_key: nil,
				model: "gpt-4o"
			)
		end
	end
end
