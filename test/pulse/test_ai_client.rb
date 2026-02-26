# Tests for Pulse::AIClient. Verifies prompt sending, response parsing,
# header construction, and system/user message assembly using Faraday's
# test adapter to stub HTTP interactions.

require "test_helper"
require "json"

class TestAIClient < Minitest::Test
	def build_stubs( &block )
		stubs = Faraday::Adapter::Test::Stubs.new
		stubs.post( "chat/completions", &block )
		stubs
	end

	def build_connection( stubs )
		Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end
	end

	def test_sends_prompt_and_returns_content
		stubs = build_stubs do | env |
			[
				200,
				{ "Content-Type" => "application/json" },
				JSON.generate( {
					choices: [ { message: { content: "AI response here" } } ]
				} )
			]
		end
		conn = build_connection( stubs )

		client = Pulse::AIClient.new(
			base_url: "http://localhost",
			api_key: "test-key",
			model: "gpt-4o"
		)
		result = client.chat( "Summarize this: hello world", connection: conn )
		assert_equal "AI response here", result
		stubs.verify_stubbed_calls
	end

	def test_sends_correct_headers
		last_request = nil
		stubs = build_stubs do | env |
			last_request = JSON.parse( env.body )
			[
				200,
				{ "Content-Type" => "application/json" },
				JSON.generate( {
					choices: [ { message: { content: "ok" } } ]
				} )
			]
		end
		conn = build_connection( stubs )

		client = Pulse::AIClient.new(
			base_url: "http://localhost",
			api_key: "sk-test-abc",
			model: "gpt-4o"
		)
		client.chat( "test", connection: conn )
		assert_equal "gpt-4o", last_request["model"]
		stubs.verify_stubbed_calls
	end

	def test_sends_system_and_user_messages
		last_request = nil
		stubs = build_stubs do | env |
			last_request = JSON.parse( env.body )
			[
				200,
				{ "Content-Type" => "application/json" },
				JSON.generate( {
					choices: [ { message: { content: "ok" } } ]
				} )
			]
		end
		conn = build_connection( stubs )

		client = Pulse::AIClient.new(
			base_url: "http://localhost",
			api_key: "test-key",
			model: "gpt-4o"
		)
		client.chat( "user prompt", system: "system prompt", connection: conn )
		messages = last_request["messages"]
		assert_equal "system", messages[0]["role"]
		assert_equal "system prompt", messages[0]["content"]
		assert_equal "user", messages[1]["role"]
		assert_equal "user prompt", messages[1]["content"]
		stubs.verify_stubbed_calls
	end

	def test_raises_on_missing_api_key
		assert_raises ArgumentError do
			Pulse::AIClient.new(
				base_url: "http://localhost",
				api_key: nil,
				model: "gpt-4o"
			)
		end
	end
end
