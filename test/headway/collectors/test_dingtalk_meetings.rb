# Tests for Headway::Collectors::DingtalkMeetings. Verifies conference
# listing, transcript fetching, and Chinese markdown formatting using
# a fake DingTalk client.

require "test_helper"

class FakeDingTalkMeetingsClient
	attr_reader :requests

	def initialize( responses = {} )
		@responses = responses
		@requests = []
	end

	def get( path, params: {} )
		@requests << { method: :get, path: path, params: params }
		@responses[path] || {}
	end
end

class TestDingtalkMeetings < Minitest::Test
	def sample_conference( overrides = {} )
		{
			"conferenceId" => "conf-001",
			"title" => "周例会",
			"startTime" => 1740528000000,
			"userList" => [
				{ "name" => "Alice" },
				{ "name" => "Bob" }
			]
		}.merge( overrides )
	end

	def sample_paragraph( overrides = {} )
		{
			"nickName" => "Alice",
			"paragraph" => "本周完成了API集成。",
			"startTime" => 1000,
			"endTime" => 5000
		}.merge( overrides )
	end

	def build_collector( conferences: [], transcripts: {} )
		responses = {
			"/v1.0/conference/videoConferences/histories" => {
				"conferenceList" => conferences
			}
		}
		transcripts.each do | conf_id, paragraphs |
			responses["/v1.0/conference/videoConferences/#{conf_id}/cloudRecords/getTexts"] = {
				"paragraphList" => paragraphs,
				"hasMore" => false
			}
		end

		client = FakeDingTalkMeetingsClient.new( responses )
		collector = Headway::Collectors::DingtalkMeetings.new(
			client: client,
			interval_hours: 168
		)
		[ collector, client ]
	end

	def test_collects_meetings_as_single_section
		collector, _client = build_collector(
			conferences: [ sample_conference ],
			transcripts: { "conf-001" => [ sample_paragraph ] }
		)
		items = collector.collect

		assert_equal 1, items.length
		assert_equal "Meetings", items[0][:name]
		assert_equal 1, items[0][:files].length
	end

	def test_formats_meeting_with_chinese_labels
		collector, _client = build_collector(
			conferences: [ sample_conference ],
			transcripts: { "conf-001" => [ sample_paragraph ] }
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# 周例会"
		assert_includes content, "**时间**:"
		assert_includes content, "**参会人**: Alice、Bob"
		assert_includes content, "## 会议记录"
		assert_includes content, "**Alice**: 本周完成了API集成。"
	end

	def test_formats_meeting_without_transcript
		collector, _client = build_collector(
			conferences: [ sample_conference ],
			transcripts: {}
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# 周例会"
		assert_includes content, "无会议记录。"
	end

	def test_multiple_speakers_in_transcript
		paragraphs = [
			sample_paragraph( "nickName" => "Alice", "paragraph" => "设计已完成。" ),
			sample_paragraph( "nickName" => "Bob", "paragraph" => "测试进行中。" )
		]
		collector, _client = build_collector(
			conferences: [ sample_conference ],
			transcripts: { "conf-001" => paragraphs }
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "**Alice**: 设计已完成。"
		assert_includes content, "**Bob**: 测试进行中。"
	end

	def test_returns_empty_for_no_conferences
		collector, _client = build_collector( conferences: [] )
		items = collector.collect

		assert_equal [], items
	end

	def test_queries_history_endpoint
		collector, client = build_collector(
			conferences: [ sample_conference ],
			transcripts: { "conf-001" => [] }
		)
		collector.collect

		history_req = client.requests.find { | r | r[:path].include?( "histories" ) }
		assert history_req, "Should query conference histories"
		assert_equal :get, history_req[:method]
	end

	def test_fetches_transcript_for_each_conference
		confs = [
			sample_conference( "conferenceId" => "conf-001", "title" => "Meeting 1" ),
			sample_conference( "conferenceId" => "conf-002", "title" => "Meeting 2" )
		]
		collector, client = build_collector(
			conferences: confs,
			transcripts: {
				"conf-001" => [ sample_paragraph( "paragraph" => "First meeting notes." ) ],
				"conf-002" => [ sample_paragraph( "paragraph" => "Second meeting notes." ) ]
			}
		)
		items = collector.collect

		assert_equal 2, items[0][:files].length
		transcript_reqs = client.requests.select { | r | r[:path].include?( "getTexts" ) }
		assert_equal 2, transcript_reqs.length
	end
end
