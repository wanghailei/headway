# Tests for Pulse::Publishers::DingtalkBotNotify. Verifies section
# parsing, highlight detection, message formatting, and delivery
# using a fake messenger.

require "test_helper"

class FakeMessenger
	attr_reader :sends

	def initialize
		@sends = []
	end

	def send_markdown( user_ids:, title:, content: )
		@sends << { user_ids: user_ids, title: title, content: content }
	end
end

class TestDingtalkBotNotify < Minitest::Test
	def setup
		@messenger = FakeMessenger.new
		@user_ids = [ "u1", "u2" ]
	end

	def build_publisher( report_url: "https://example.com/report" )
		Pulse::Publishers::DingtalkBotNotify.new(
			messenger: @messenger,
			user_ids: @user_ids,
			report_url: report_url
		)
	end

	def test_highlights_red_and_yellow_items
		report = <<~MD
			### 🔴 Server outage
			Critical production issue. All hands on deck.

			### 🟡 Budget review
			Needs attention before end of month.

			### 🟢 Feature rollout
			Everything on track.
		MD

		build_publisher.publish( report )

		assert_equal 1, @messenger.sends.size
		content = @messenger.sends.first[:content]
		assert_includes content, "Server outage"
		assert_includes content, "Budget review"
		assert_includes content, "需要关注"
		assert_includes content, "1 项正常进行中"
	end

	def test_highlights_tagged_items
		report = <<~MD
			### 🟢 Deploy fix %P0%
			Urgent fix tagged for priority.

			### 🟢 Regular update
			Nothing special.
		MD

		build_publisher.publish( report )

		content = @messenger.sends.first[:content]
		assert_includes content, "Deploy fix"
		assert_includes content, "1 项正常进行中"
	end

	def test_includes_report_url_in_normal_items
		report = <<~MD
			### 🟢 Item A
			Normal.

			### 🟢 Item B
			Also normal.
		MD

		build_publisher( report_url: "https://example.com/r" ).publish( report )

		content = @messenger.sends.first[:content]
		assert_includes content, "https://example.com/r"
		assert_includes content, "2 项正常进行中"
	end

	def test_no_report_url_shows_plain_label
		report = <<~MD
			### 🟢 Item A
			Normal.
		MD

		build_publisher( report_url: nil ).publish( report )

		content = @messenger.sends.first[:content]
		assert_includes content, "1 项正常进行中"
		refute_includes content, "]()"
	end

	def test_skips_when_no_user_ids
		publisher = Pulse::Publishers::DingtalkBotNotify.new(
			messenger: @messenger,
			user_ids: [],
			report_url: nil
		)
		publisher.publish( "### 🔴 Something\nBad." )

		assert_empty @messenger.sends
	end

	def test_handles_empty_report
		build_publisher.publish( "" )
		assert_empty @messenger.sends
	end

	def test_sends_to_correct_user_ids
		report = "### 🔴 Issue\nDetails."
		build_publisher.publish( report )

		assert_equal [ "u1", "u2" ], @messenger.sends.first[:user_ids]
	end

	def test_completed_items_are_not_highlighted
		report = <<~MD
			### ✅ Completed task
			All done.

			### 🔴 Active issue
			Still happening.
		MD

		build_publisher.publish( report )

		content = @messenger.sends.first[:content]
		assert_includes content, "Active issue"
		assert_includes content, "1 项正常进行中"
	end
end
