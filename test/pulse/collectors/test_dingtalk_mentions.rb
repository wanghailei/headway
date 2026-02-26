# Tests for Pulse::Collectors::DingtalkMentions. Verifies queue draining,
# message formatting, empty queue behavior, and doc enrichment.

require "test_helper"

# Fake doc reader for testing doc enrichment in mentions.
class FakeDocReader
	def initialize( docs = {} )
		@docs = docs
	end

	def fetch( url, **_opts )
		@docs[url]
	end
end

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

	def test_enriches_mention_with_doc_content
		doc_url = "https://alidocs.dingtalk.com/i/nodes/abc123"
		doc_reader = FakeDocReader.new( doc_url => "# Project Plan\n\nDetails here." )

		queue = Thread::Queue.new
		queue << {
			"senderNick" => "Alice",
			"text" => { "content" => "请看文档 #{doc_url}" },
			"createAt" => 1700000000000
		}

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue, doc_reader: doc_reader )
		result = collector.collect

		content = result.first[:files].first[:content]
		assert_includes content, "请看文档"
		assert_includes content, "附件文档"
		assert_includes content, "# Project Plan"
		assert_includes content, "Details here."
	end

	def test_no_enrichment_without_doc_reader
		queue = Thread::Queue.new
		queue << {
			"senderNick" => "Bob",
			"text" => { "content" => "看看 https://alidocs.dingtalk.com/i/nodes/xyz" }
		}

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue )
		result = collector.collect

		content = result.first[:files].first[:content]
		assert_includes content, "alidocs.dingtalk.com"
		refute_includes content, "附件文档"
	end

	def test_enrichment_skips_failed_doc_fetch
		doc_reader = FakeDocReader.new # no docs → returns nil for all

		queue = Thread::Queue.new
		queue << {
			"senderNick" => "Carol",
			"text" => { "content" => "https://alidocs.dingtalk.com/i/nodes/fail" }
		}

		collector = Pulse::Collectors::DingtalkMentions.new( queue: queue, doc_reader: doc_reader )
		result = collector.collect

		content = result.first[:files].first[:content]
		refute_includes content, "附件文档"
	end
end
