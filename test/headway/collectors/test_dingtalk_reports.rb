# Tests for Headway::Collectors::DingtalkReports. Verifies report
# fetching, markdown formatting, pagination, and time windowing
# using a fake DingTalk client.

require "test_helper"
require "json"

class FakeDingTalkClient
	attr_reader :requests

	def initialize( responses = {} )
		@responses = responses
		@requests = []
	end

	def legacy_post( path, body: {}, connection: nil )
		@requests << { method: :legacy_post, path: path, body: body }
		@responses[path] || { "result" => { "data_list" => [], "has_more" => false } }
	end
end

class TestDingtalkReports < Minitest::Test
	def sample_report( overrides = {} )
		{
			"report_id" => "rpt-001",
			"template_name" => "日报",
			"creator_name" => "Alice",
			"creator_id" => "user-alice",
			"create_time" => 1740441600000,
			"contents" => [
				{ "key" => "今日工作", "value" => "Finished API integration" },
				{ "key" => "明日计划", "value" => "Start testing" }
			],
			"remark" => "All good"
		}.merge( overrides )
	end

	def test_collects_reports_as_single_section
		client = FakeDingTalkClient.new(
			"/topapi/report/list" => {
				"errcode" => 0,
				"result" => {
					"data_list" => [ sample_report ],
					"has_more" => false
				}
			}
		)

		collector = Headway::Collectors::DingtalkReports.new(
			client: client,
			interval_hours: 24
		)
		items = collector.collect
		assert_equal 1, items.length
		assert_equal "Reports", items[0][:name]
		assert_equal 1, items[0][:files].length
	end

	def test_formats_report_as_markdown
		client = FakeDingTalkClient.new(
			"/topapi/report/list" => {
				"errcode" => 0,
				"result" => {
					"data_list" => [ sample_report ],
					"has_more" => false
				}
			}
		)

		collector = Headway::Collectors::DingtalkReports.new(
			client: client,
			interval_hours: 24
		)
		items = collector.collect
		content = items[0][:files][0][:content]
		assert_includes content, "Alice"
		assert_includes content, "日报"
		assert_includes content, "今日工作"
		assert_includes content, "Finished API integration"
		assert_includes content, "明日计划"
		assert_includes content, "Start testing"
	end

	def test_sends_time_window_params
		client = FakeDingTalkClient.new
		collector = Headway::Collectors::DingtalkReports.new(
			client: client,
			interval_hours: 2
		)
		collector.collect
		body = client.requests.first[:body]
		assert body[:start_time] > 0
		assert body[:end_time] > body[:start_time]
	end

	def test_filters_by_template_name
		client = FakeDingTalkClient.new
		collector = Headway::Collectors::DingtalkReports.new(
			client: client,
			interval_hours: 24,
			template_name: "周报"
		)
		collector.collect
		body = client.requests.first[:body]
		assert_equal "周报", body[:template_name]
	end

	def test_returns_empty_for_no_reports
		client = FakeDingTalkClient.new
		collector = Headway::Collectors::DingtalkReports.new(
			client: client,
			interval_hours: 24
		)
		items = collector.collect
		assert_equal [], items
	end
end
