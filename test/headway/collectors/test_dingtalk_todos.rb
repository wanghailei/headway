# Tests for Headway::Collectors::DingtalkTodos. Verifies that todos
# are fetched from all employees, formatted as Chinese markdown, sorted
# by due date, and returned as a single "Tasks" section.

require "test_helper"

class FakeDingTalkTodosClient
	attr_reader :requests

	def initialize( employees: [], todo_responses: {} )
		@employees = employees
		@todo_responses = todo_responses
		@requests = []
	end

	def list_employees
		@employees
	end

	def post( path, body: {} )
		@requests << { method: :post, path: path, body: body }
		@todo_responses[path] || { "todoCards" => [], "totalCount" => 0 }
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

	def sample_employees
		[
			{ userid: "user-alice", name: "Alice", unionid: "union-alice", dept_id: 1 },
			{ userid: "user-bob", name: "Bob", unionid: "union-bob", dept_id: 2 }
		]
	end

	def build_collector( employees: sample_employees, todo_responses: {} )
		client = FakeDingTalkTodosClient.new(
			employees: employees,
			todo_responses: todo_responses
		)
		collector = Headway::Collectors::DingtalkTodos.new( client: client )
		[ collector, client ]
	end

	def test_collects_tasks_from_multiple_employees
		todos = {
			"/v1.0/todo/users/union-alice/org/tasks/query" => {
				"todoCards" => [ sample_task( "subject" => "Alice task" ) ],
				"totalCount" => 1
			},
			"/v1.0/todo/users/union-bob/org/tasks/query" => {
				"todoCards" => [ sample_task( "subject" => "Bob task" ) ],
				"totalCount" => 1
			}
		}
		collector, _client = build_collector( todo_responses: todos )
		items = collector.collect

		assert_equal 1, items.length
		assert_equal "Tasks", items[0][:name]
		assert_equal 2, items[0][:files].length
	end

	def test_queries_org_tasks_endpoint
		todos = {
			"/v1.0/todo/users/union-alice/org/tasks/query" => {
				"todoCards" => [ sample_task ],
				"totalCount" => 1
			}
		}
		collector, client = build_collector(
			employees: [ { userid: "user-alice", name: "Alice", unionid: "union-alice", dept_id: 1 } ],
			todo_responses: todos
		)
		collector.collect

		req = client.requests.first
		assert_equal :post, req[:method]
		assert_includes req[:path], "/org/tasks/query"
		assert_equal( { isDone: false }, req[:body] )
	end

	def test_formats_task_with_chinese_labels
		todos = {
			"/v1.0/todo/users/union-alice/org/tasks/query" => {
				"todoCards" => [ sample_task ],
				"totalCount" => 1
			}
		}
		collector, _client = build_collector(
			employees: [ { userid: "user-alice", name: "Alice", unionid: "union-alice", dept_id: 1 } ],
			todo_responses: todos
		)
		items = collector.collect
		content = items[0][:files][0][:content]

		assert_includes content, "# Complete API integration"
		assert_includes content, "**负责人**: Alice"
		assert_includes content, "**状态**: 待办"
		assert_includes content, "**优先级**: 高"
		assert_includes content, "Implement all endpoints"
	end

	def test_priority_labels_in_chinese
		priorities = { 10 => "紧急", 20 => "高", 30 => "中", 40 => "低" }

		priorities.each do | level, label |
			task = sample_task( "priority" => level )
			todos = {
				"/v1.0/todo/users/union-alice/org/tasks/query" => {
					"todoCards" => [ task ],
					"totalCount" => 1
				}
			}
			collector, _client = build_collector(
				employees: [ { userid: "user-alice", name: "Alice", unionid: "union-alice", dept_id: 1 } ],
				todo_responses: todos
			)
			items = collector.collect
			content = items[0][:files][0][:content]

			assert_includes content, "**优先级**: #{label}", "Priority #{level} should be #{label}"
		end
	end

	def test_sorts_by_due_date_earliest_first
		early = sample_task( "subject" => "Early task", "dueTime" => 1740441600000 )
		late = sample_task( "subject" => "Late task", "dueTime" => 1740700800000 )

		todos = {
			"/v1.0/todo/users/union-alice/org/tasks/query" => {
				"todoCards" => [ late, early ],
				"totalCount" => 2
			}
		}
		collector, _client = build_collector(
			employees: [ { userid: "user-alice", name: "Alice", unionid: "union-alice", dept_id: 1 } ],
			todo_responses: todos
		)
		items = collector.collect
		filenames = items[0][:files].map { | f | f[:filename] }

		assert_match( /early-task/, filenames[0] )
		assert_match( /late-task/, filenames[1] )
	end

	def test_returns_empty_for_no_tasks
		collector, _client = build_collector( todo_responses: {} )
		items = collector.collect

		assert_equal [], items
	end

	def test_skips_employees_without_unionid
		employees = [
			{ userid: "user-alice", name: "Alice", unionid: nil, dept_id: 1 },
			{ userid: "user-bob", name: "Bob", unionid: "union-bob", dept_id: 2 }
		]
		todos = {
			"/v1.0/todo/users/union-bob/org/tasks/query" => {
				"todoCards" => [ sample_task( "subject" => "Bob task" ) ],
				"totalCount" => 1
			}
		}
		collector, _client = build_collector( employees: employees, todo_responses: todos )
		items = collector.collect

		assert_equal 1, items.length
		assert_equal 1, items[0][:files].length
		assert_includes items[0][:files][0][:content], "Bob"
	end
end
