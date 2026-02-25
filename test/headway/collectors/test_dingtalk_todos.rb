# Tests for Headway::Collectors::DingtalkTodos. Verifies task
# fetching, markdown formatting, due-date sorting, and priority
# labels using a fake DingTalk client.

require "test_helper"

class FakeDingTalkTodosClient
	attr_reader :requests

	def initialize( responses = {} )
		@responses = responses
		@requests = []
	end

	def post( path, body: {} )
		@requests << { method: :post, path: path, body: body }
		@responses[path] || { "todoCards" => [], "nextToken" => nil }
	end
end

class TestDingtalkTodos < Minitest::Test
	def sample_task( overrides = {} )
		{
			"taskId" => "task-001",
			"subject" => "Complete API integration",
			"description" => "Implement all endpoints",
			"dueTime" => 1740528000000,
			"priority" => 20,
			"isDone" => false,
			"creatorId" => "user-alice"
		}.merge( overrides )
	end

	def build_collector( tasks )
		client = FakeDingTalkTodosClient.new(
			"/v1.0/todo/users/union-123/tasks/query" => {
				"todoCards" => tasks,
				"nextToken" => nil
			}
		)
		collector = Headway::Collectors::DingtalkTodos.new(
			client: client,
			operator_user_id: "union-123"
		)
		[ collector, client ]
	end

	def test_collects_tasks_as_single_section
		collector, _client = build_collector( [ sample_task ] )
		items = collector.collect

		assert_equal 1, items.length
		assert_equal "Tasks", items[0][:name]
		assert_equal 1, items[0][:files].length
	end

	def test_posts_to_correct_endpoint
		collector, client = build_collector( [ sample_task ] )
		collector.collect

		req = client.requests.first
		assert_equal :post, req[:method]
		assert_equal "/v1.0/todo/users/union-123/tasks/query", req[:path]
		assert_equal( { isDone: false }, req[:body] )
	end

	def test_formats_task_as_structured_markdown
		collector, _client = build_collector( [ sample_task ] )
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# Complete API integration"
		assert_includes content, "**Status**: Pending"
		assert_includes content, "**Due**: 2025-02-26"
		assert_includes content, "**Priority**: High"
		assert_includes content, "Implement all endpoints"
	end

	def test_formats_done_task_status
		task = sample_task( "isDone" => true )
		collector, _client = build_collector( [ task ] )
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "**Status**: Done"
	end

	def test_priority_labels
		priorities = { 10 => "Urgent", 20 => "High", 30 => "Medium", 40 => "Low" }

		priorities.each do | level, label |
			task = sample_task( "priority" => level )
			collector, _client = build_collector( [ task ] )
			items = collector.collect
			content = items[0][:files][0][:content]

			assert_includes content, "**Priority**: #{label}", "Priority #{level} should be labeled #{label}"
		end
	end

	def test_sorts_by_due_date_earliest_first
		early = sample_task(
			"taskId" => "task-early",
			"subject" => "Early task",
			"dueTime" => 1740441600000
		)
		late = sample_task(
			"taskId" => "task-late",
			"subject" => "Late task",
			"dueTime" => 1740700800000
		)

		collector, _client = build_collector( [ late, early ] )
		items = collector.collect
		filenames = items[0][:files].map do | f |
			f[:filename]
		end

		assert_match( /early-task/, filenames[0] )
		assert_match( /late-task/, filenames[1] )
	end

	def test_nil_due_date_sorted_last
		with_due = sample_task(
			"taskId" => "task-with-due",
			"subject" => "Has due date",
			"dueTime" => 1740528000000
		)
		without_due = sample_task(
			"taskId" => "task-no-due",
			"subject" => "No due date",
			"dueTime" => nil
		)

		collector, _client = build_collector( [ without_due, with_due ] )
		items = collector.collect
		filenames = items[0][:files].map do | f |
			f[:filename]
		end

		assert_match( /has-due-date/, filenames[0] )
		assert_match( /no-due-date/, filenames[1] )
	end

	def test_returns_empty_for_no_tasks
		collector, _client = build_collector( [] )
		items = collector.collect

		assert_equal [], items
	end

	def test_task_without_description
		task = sample_task( "description" => nil )
		collector, _client = build_collector( [ task ] )
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# Complete API integration"
		refute_includes content, "nil"
	end
end
