# Tests for Headway::Collectors::DingtalkMeetings. Verifies meeting
# transcript fetching, markdown formatting, empty results, and
# graceful handling of missing transcripts using a fake client.

require "test_helper"

class FakeDingTalkMeetingsClient
	attr_reader :requests

	def initialize( responses = {} )
		@responses = responses
		@requests = []
	end

	def post( path, body: {} )
		@requests << { method: :post, path: path, body: body }
		@responses[path] || { "conferenceList" => [] }
	end

	def get( path )
		@requests << { method: :get, path: path }
		@responses[path] || { "paragraphList" => [] }
	end
end

class TestDingtalkMeetings < Minitest::Test
	def sample_conference( overrides = {} )
		{
			"conferenceId" => "conf-001",
			"title" => "Sprint Planning",
			"startTime" => 1740441600000,
			"userList" => [
				{ "name" => "Alice" },
				{ "name" => "Bob" }
			]
		}.merge( overrides )
	end

	def sample_transcript
		{
			"paragraphList" => [
				{
					"speakerName" => "Alice",
					"paragraphContent" => "Let's discuss the sprint goals."
				},
				{
					"speakerName" => "Bob",
					"paragraphContent" => "I think we should focus on the API."
				}
			]
		}
	end

	def build_collector( conferences, transcripts = {} )
		responses = {}
		responses["/v1.0/conference/videoConferences/query"] = {
			"conferenceList" => conferences
		}
		transcripts.each do | conf_id, transcript |
			responses["/v1.0/conference/videoConferences/#{conf_id}/recordings/transcripts"] = transcript
		end

		client = FakeDingTalkMeetingsClient.new( responses )
		collector = Headway::Collectors::DingtalkMeetings.new(
			client: client,
			interval_hours: 2
		)
		[ collector, client ]
	end

	def test_collects_meetings_as_single_section
		collector, _client = build_collector(
			[ sample_conference ],
			{ "conf-001" => sample_transcript }
		)
		items = collector.collect

		assert_equal 1, items.length
		assert_equal "Meeting Notes", items[0][:name]
		assert_equal 1, items[0][:files].length
	end

	def test_formats_meeting_with_title_date_participants_transcript
		collector, _client = build_collector(
			[ sample_conference ],
			{ "conf-001" => sample_transcript }
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# Sprint Planning"
		assert_includes content, "**Date**: 2025-02-25"
		assert_includes content, "**Participants**: Alice, Bob"
		assert_includes content, "## Transcript"
		assert_includes content, "**Alice**: Let's discuss the sprint goals."
		assert_includes content, "**Bob**: I think we should focus on the API."
	end

	def test_generates_filename_from_date_and_title
		collector, _client = build_collector(
			[ sample_conference ],
			{ "conf-001" => sample_transcript }
		)
		items = collector.collect
		filename = items[0][:files][0][:filename]

		assert_equal "2025-02-25-sprint-planning", filename
	end

	def test_returns_empty_for_no_meetings
		collector, _client = build_collector( [] )
		items = collector.collect

		assert_equal [], items
	end

	def test_handles_missing_transcript_gracefully
		collector, _client = build_collector(
			[ sample_conference ],
			{}
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# Sprint Planning"
		assert_includes content, "## Transcript"
		assert_includes content, "No transcript available."
	end

	def test_sends_time_window_in_query
		collector, client = build_collector( [] )
		collector.collect

		req = client.requests.first
		assert_equal :post, req[:method]
		assert_equal "/v1.0/conference/videoConferences/query", req[:path]
		assert req[:body][:startTime] > 0
		assert req[:body][:endTime] > req[:body][:startTime]
	end

	def test_fetches_transcript_for_each_meeting
		conf_a = sample_conference( "conferenceId" => "conf-a", "title" => "Meeting A" )
		conf_b = sample_conference( "conferenceId" => "conf-b", "title" => "Meeting B" )
		collector, client = build_collector(
			[ conf_a, conf_b ],
			{
				"conf-a" => sample_transcript,
				"conf-b" => sample_transcript
			}
		)
		items = collector.collect

		assert_equal 2, items[0][:files].length

		get_requests = client.requests.select do | r |
			r[:method] == :get
		end
		assert_equal 2, get_requests.length
	end
end
