# Tests for Pulse::DingTalk::BotMessenger. Verifies batch sending,
# user list chunking, and content truncation using a fake client.

require "test_helper"
require "json"

class FakeBotClient
	attr_reader :posts

	def initialize
		@posts = []
	end

	def post( path, body: {} )
		@posts << { path: path, body: body }
		{}
	end
end

class TestBotMessenger < Minitest::Test
	def setup
		@client = FakeBotClient.new
		@messenger = Pulse::DingTalk::BotMessenger.new( client: @client, robot_code: "robot123" )
	end

	def test_sends_markdown_to_users
		@messenger.send_markdown(
			user_ids: [ "u1", "u2" ],
			title: "Report",
			content: "# Hello"
		)

		assert_equal 1, @client.posts.size
		post = @client.posts.first
		assert_equal Pulse::DingTalk::BotMessenger::BATCH_SEND_PATH, post[:path]
		assert_equal "robot123", post[:body][:robotCode]
		assert_equal [ "u1", "u2" ], post[:body][:userIds]
		assert_equal "sampleMarkdown", post[:body][:msgKey]

		params = JSON.parse( post[:body][:msgParam] )
		assert_equal "Report", params["title"]
		assert_equal "# Hello", params["text"]
	end

	def test_batches_large_user_lists
		user_ids = ( 1..25 ).map { | i | "user#{i}" }
		@messenger.send_markdown( user_ids: user_ids, title: "T", content: "C" )

		assert_equal 2, @client.posts.size
		assert_equal 20, @client.posts[0][:body][:userIds].size
		assert_equal 5, @client.posts[1][:body][:userIds].size
	end

	def test_truncates_long_content
		long_content = "x" * 25_000
		@messenger.send_markdown( user_ids: [ "u1" ], title: "T", content: long_content )

		params = JSON.parse( @client.posts.first[:body][:msgParam] )
		assert params["text"].length <= Pulse::DingTalk::BotMessenger::MAX_CONTENT_LENGTH + 20
		assert params["text"].end_with?( "...(truncated)" )
	end

	def test_does_not_truncate_short_content
		@messenger.send_markdown( user_ids: [ "u1" ], title: "T", content: "Short" )

		params = JSON.parse( @client.posts.first[:body][:msgParam] )
		assert_equal "Short", params["text"]
	end

	def test_skips_nil_user_ids
		@messenger.send_markdown( user_ids: nil, title: "T", content: "C" )
		assert_empty @client.posts
	end

	def test_skips_empty_user_ids
		@messenger.send_markdown( user_ids: [], title: "T", content: "C" )
		assert_empty @client.posts
	end
end
