# Tests for Headway::AIClient. Verifies prompt sending, response parsing,
# header construction, and system/user message assembly against a local
# WEBrick server that mimics the OpenAI chat completions endpoint.

require "test_helper"
require "headway/ai_client"
require "webrick"
require "json"

class TestAIClient < Minitest::Test
	def setup
		@server = WEBrick::HTTPServer.new(
			Port: 0,
			Logger: WEBrick::Log.new( "/dev/null" ),
			AccessLog: []
		)
		@port = @server.config[:Port]

		@server.mount_proc "/v1/chat/completions" do | req, res |
			body = JSON.parse( req.body )
			@last_request = body
			res.content_type = "application/json"
			res.body = JSON.generate( {
				choices: [ { message: { content: "AI response here" } } ]
			} )
		end

		@thread = Thread.new do
			@server.start
		end
	end

	def teardown
		@server.shutdown
		@thread.join
	end

	def test_sends_prompt_and_returns_content
		client = Headway::AIClient.new(
			base_url: "http://localhost:#{@port}/v1",
			api_key: "test-key",
			model: "gpt-4o"
		)
		result = client.chat( "Summarize this: hello world" )
		assert_equal "AI response here", result
	end

	def test_sends_correct_headers
		client = Headway::AIClient.new(
			base_url: "http://localhost:#{@port}/v1",
			api_key: "sk-test-abc",
			model: "gpt-4o"
		)
		client.chat( "test" )
		assert_equal "gpt-4o", @last_request["model"]
	end

	def test_sends_system_and_user_messages
		client = Headway::AIClient.new(
			base_url: "http://localhost:#{@port}/v1",
			api_key: "test-key",
			model: "gpt-4o"
		)
		client.chat( "user prompt", system: "system prompt" )
		messages = @last_request["messages"]
		assert_equal "system", messages[0]["role"]
		assert_equal "system prompt", messages[0]["content"]
		assert_equal "user", messages[1]["role"]
		assert_equal "user prompt", messages[1]["content"]
	end
end
