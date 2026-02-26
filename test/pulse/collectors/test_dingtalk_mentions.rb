# Tests for Pulse::Collectors::DingtalkMentions. Verifies queue draining,
# message formatting, and empty queue behavior using a real Thread::Queue.

require "test_helper"

class TestDingtalkMentions < Minitest::Test
	def test_drains_queue_and_formats_mentions
		queue = Thread::Queue.new
		queue << {
			"senderNick" => "Alice",
			"text" => { "content" => " check the budget " },
			"createAt" => 1700000000000
		}
		queue << {
			"senderNick" => "Bob",
			"text" => { "content" => "update on project X" },
			"createAt" => 1700003600000
		}

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue )
		result = collector.collect

		assert_equal 1, result.size
		assert_equal "Bot Mentions", result.first[:name]
		assert_equal 2, result.first[:files].size

		first = result.first[:files].first
		assert_includes first[:content], "Alice"
		assert_includes first[:content], "check the budget"
		assert_includes first[:filename], "Alice"
	end

	def test_returns_empty_for_empty_queue
		queue = Thread::Queue.new
		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue )
		result = collector.collect

		assert_equal [], result
	end

	def test_queue_is_drained_after_collect
		queue = Thread::Queue.new
		queue << { "senderNick" => "Alice", "text" => { "content" => "hi" } }

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue )
		collector.collect

		assert queue.empty?
	end

	def test_handles_missing_fields
		queue = Thread::Queue.new
		queue << { "senderNick" => nil, "content" => "raw content" }

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue )
		result = collector.collect

		assert_equal 1, result.size
		first = result.first[:files].first
		assert_includes first[:content], "unknown"
		assert_includes first[:content], "raw content"
	end
end
