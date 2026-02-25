# Tests for Headway::Publishers::DingtalkDoc. Verifies that the
# publisher sends markdown content to the correct DingTalk Doc API
# endpoint with proper body parameters using a fake client.

require "test_helper"

class FakeDingTalkDocClient
	attr_reader :requests

	def initialize
		@requests = []
	end

	def post( path, body: {} )
		@requests << { method: :post, path: path, body: body }
		{}
	end
end

class TestDingtalkDocPublisher < Minitest::Test
	def setup
		@client = FakeDingTalkDocClient.new
		@publisher = Headway::Publishers::DingtalkDoc.new(
			client: @client,
			space_id: "space-123",
			doc_id: "doc-456",
			operator_user_id: "user-789"
		)
	end

	def test_posts_to_correct_api_path
		@publisher.publish( "# Report" )

		req = @client.requests.first
		assert_equal :post, req[:method]
		assert_equal "/v1.0/doc/spaces/space-123/docs/doc-456/contents/update", req[:path]
	end

	def test_sends_operator_id_in_body
		@publisher.publish( "# Report" )

		body = @client.requests.first[:body]
		assert_equal "user-789", body[:operatorId]
	end

	def test_sends_source_format_markdown_in_body
		@publisher.publish( "# Report" )

		body = @client.requests.first[:body]
		assert_equal "markdown", body[:sourceFormat]
	end

	def test_sends_content_in_body
		@publisher.publish( "# Weekly Report\n\nAll good." )

		body = @client.requests.first[:body]
		assert_equal "# Weekly Report\n\nAll good.", body[:content]
	end
end
