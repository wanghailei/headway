# DingTalk Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Connect Headway to DingTalk so it auto-collects Reports (日志), Todos, and Meeting Notes, then publishes the synthesized report to a living DingTalk Doc.

**Architecture:** A shared `DingTalk::Client` handles auth + token lifecycle. Three collectors and one publisher share that client. Runner lazily creates the client only when DingTalk types appear in config.

**Tech Stack:** Ruby, Faraday (HTTP), Zeitwerk (autoloading), minitest + Faraday test stubs

**Coding style:** Tabs, spaces inside parens `method( arg )`, spaces inside block pipes `do | x |`, `do...end` blocks, file overview comments, outdented `private`.

**Test command:** `bundle exec ruby -Ilib -Itest -e 'Dir["test/**/test_*.rb"].each { |f| require "./#{f}" }'`

---

### Task 1: DingTalk::Client — Auth + Token Management

**Files:**
- Create: `lib/headway/dingtalk/client.rb`
- Create: `test/headway/dingtalk/test_client.rb`
- Modify: `lib/headway.rb` (add Zeitwerk inflection)

**Step 1: Add Zeitwerk inflection**

In `lib/headway.rb`, add `"dingtalk" => "DingTalk"` to the inflector:

```ruby
loader.inflector.inflect(
	"ai_client" => "AIClient",
	"cli" => "CLI",
	"dingtalk" => "DingTalk"
)
```

**Step 2: Write the tests**

Create `test/headway/dingtalk/test_client.rb`:

```ruby
# Tests for Headway::DingTalk::Client. Verifies token fetching, caching,
# refresh, header injection, and error handling using Faraday test stubs.

require "test_helper"
require "json"

class TestDingTalkClient < Minitest::Test
	def auth_response( token: "test-token", expire_in: 7200 )
		JSON.generate( { accessToken: token, expireIn: expire_in } )
	end

	def build_stubs( &block )
		Faraday::Adapter::Test::Stubs.new( &block )
	end

	def build_connection( stubs )
		Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end
	end

	def test_fetches_token_and_sends_header
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/todo/users/u1/tasks" ) do | env |
				assert_equal "test-token", env.request_headers["x-acs-dingtalk-access-token"]
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( { items: [] } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		result = client.get( "/v1.0/todo/users/u1/tasks", connection: conn )
		assert_equal( { "items" => [] }, result )
		stubs.verify_stubbed_calls
	end

	def test_caches_token_across_requests
		auth_calls = 0
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				auth_calls += 1
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/first" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
			stub.get( "/v1.0/second" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.get( "/v1.0/first", connection: conn )
		client.get( "/v1.0/second", connection: conn )
		assert_equal 1, auth_calls
	end

	def test_refreshes_expired_token
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/data" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		# Force token to be expired
		client.instance_variable_set( :@token, "old" )
		client.instance_variable_set( :@token_expires_at, Time.now - 1 )
		client.get( "/v1.0/data", connection: conn )
		assert_equal "test-token", client.instance_variable_get( :@token )
	end

	def test_post_sends_body
		last_body = nil
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/v1.0/doc/update" ) do | env |
				last_body = JSON.parse( env.body )
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.post( "/v1.0/doc/update", body: { content: "hello" }, connection: conn )
		assert_equal "hello", last_body["content"]
	end

	def test_legacy_post_uses_oapi_host_and_query_token
		last_env = nil
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.post( "/topapi/report/list" ) do | env |
				last_env = env
				[ 200, { "Content-Type" => "application/json" }, JSON.generate( { result: {} } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		client.legacy_post( "/topapi/report/list", body: { cursor: 0 }, connection: conn )
		assert_includes last_env.url.to_s, "access_token=test-token"
	end

	def test_raises_auth_error_on_failed_auth
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 401, { "Content-Type" => "application/json" }, JSON.generate( { message: "invalid" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "bad", app_secret: "bad" )
		assert_raises( Headway::DingTalk::Client::AuthError ) do
			client.get( "/v1.0/anything", connection: conn )
		end
	end

	def test_raises_api_error_on_failed_request
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do | env |
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v1.0/bad" ) do | env |
				[ 500, { "Content-Type" => "application/json" }, JSON.generate( { message: "server error" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Headway::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		assert_raises( Headway::DingTalk::Client::APIError ) do
			client.get( "/v1.0/bad", connection: conn )
		end
	end

	def test_raises_on_missing_app_key
		assert_raises( ArgumentError ) do
			Headway::DingTalk::Client.new( app_key: nil, app_secret: "secret" )
		end
	end

	def test_raises_on_missing_app_secret
		assert_raises( ArgumentError ) do
			Headway::DingTalk::Client.new( app_key: "key", app_secret: nil )
		end
	end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib -Itest -e 'Dir["test/**/test_*.rb"].each { |f| require "./#{f}" }'`
Expected: Errors — `Headway::DingTalk::Client` not defined

**Step 4: Write implementation**

Create `lib/headway/dingtalk/client.rb`:

```ruby
# Shared DingTalk API client with automatic token management. Handles
# authentication via AppKey/AppSecret, token caching, and automatic
# refresh when tokens expire. All DingTalk collectors and publishers
# share a single Client instance per run.

require "faraday"

module Headway
	module DingTalk
		class Client
			class APIError < StandardError; end
			class AuthError < APIError; end

			BASE_URL = "https://api.dingtalk.com"
			LEGACY_BASE_URL = "https://oapi.dingtalk.com"
			EXPIRY_BUFFER_SECONDS = 300

			def initialize( app_key:, app_secret: )
				raise ArgumentError, "app_key is required (set DINGTALK_APP_KEY)" unless app_key
				raise ArgumentError, "app_secret is required (set DINGTALK_APP_SECRET)" unless app_secret
				@app_key = app_key
				@app_secret = app_secret
				@token = nil
				@token_expires_at = nil
			end

			# GET request to new API (api.dingtalk.com).
			def get( path, params: {}, connection: nil )
				conn = connection || build_connection
				ensure_token( connection: connection )
				response = conn.get( path ) do | req |
					req.params.merge!( params )
					req.headers["x-acs-dingtalk-access-token"] = @token
				end
				handle_response( response )
			end

			# POST request to new API (api.dingtalk.com).
			def post( path, body: {}, connection: nil )
				conn = connection || build_connection
				ensure_token( connection: connection )
				response = conn.post( path, body ) do | req |
					req.headers["x-acs-dingtalk-access-token"] = @token
				end
				handle_response( response )
			end

			# POST request to legacy API (oapi.dingtalk.com).
			# Token passed as query param instead of header.
			def legacy_post( path, body: {}, connection: nil )
				conn = connection || build_legacy_connection
				ensure_token( connection: connection )
				response = conn.post( path, body ) do | req |
					req.params["access_token"] = @token
				end
				handle_response( response )
			end

		private

			def ensure_token( connection: nil )
				return if @token && @token_expires_at && Time.now < @token_expires_at
				fetch_token( connection: connection )
			end

			def fetch_token( connection: nil )
				conn = connection || build_connection
				response = conn.post( "v1.0/oauth2/accessToken", {
					appKey: @app_key,
					appSecret: @app_secret
				} )

				unless response.success?
					raise AuthError, "DingTalk auth failed: #{response.status}"
				end

				body = response.body
				@token = body["accessToken"]
				expires_in = body["expireIn"] || 7200
				@token_expires_at = Time.now + expires_in - EXPIRY_BUFFER_SECONDS
			end

			def build_connection
				Faraday.new( url: BASE_URL ) do | f |
					f.request :json
					f.response :json
					f.adapter Faraday.default_adapter
				end
			end

			def build_legacy_connection
				Faraday.new( url: LEGACY_BASE_URL ) do | f |
					f.request :json
					f.response :json
					f.adapter Faraday.default_adapter
				end
			end

			def handle_response( response )
				unless response.success?
					error_msg = response.body.is_a?( Hash ) ? response.body["message"] : nil
					raise APIError, "DingTalk API returned #{response.status}: #{error_msg || response.body.to_s}"
				end
				response.body
			end
		end
	end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib -Itest -e 'Dir["test/**/test_*.rb"].each { |f| require "./#{f}" }'`
Expected: All pass

**Step 6: Commit**

```bash
git add lib/headway.rb lib/headway/dingtalk/client.rb test/headway/dingtalk/test_client.rb
git commit -m "feat: DingTalk API client with token lifecycle management"
```

---

### Task 2: Config — DingTalk Credentials

**Files:**
- Modify: `lib/headway/config.rb`
- Modify: `test/headway/test_config.rb`
- Modify: `.env.example`

**Step 1: Write the tests**

Add to `test/headway/test_config.rb`:

```ruby
def test_dingtalk_app_key_from_env
	ENV["DINGTALK_APP_KEY"] = "dk-test-key"
	config = Headway::Config.new( @config_path )
	assert_equal "dk-test-key", config.dingtalk_app_key
ensure
	ENV.delete( "DINGTALK_APP_KEY" )
end

def test_dingtalk_app_secret_from_env
	ENV["DINGTALK_APP_SECRET"] = "dk-test-secret"
	config = Headway::Config.new( @config_path )
	assert_equal "dk-test-secret", config.dingtalk_app_secret
ensure
	ENV.delete( "DINGTALK_APP_SECRET" )
end

def test_dingtalk_credentials_nil_when_unset
	ENV.delete( "DINGTALK_APP_KEY" )
	ENV.delete( "DINGTALK_APP_SECRET" )
	config = Headway::Config.new( @config_path )
	assert_nil config.dingtalk_app_key
	assert_nil config.dingtalk_app_secret
end
```

**Step 2: Run tests to verify they fail**

Expected: `NoMethodError: undefined method 'dingtalk_app_key'`

**Step 3: Write implementation**

Add to `lib/headway/config.rb` after the `interval_hours` method, before `private`:

```ruby
def dingtalk_app_key
	ENV["DINGTALK_APP_KEY"]
end

def dingtalk_app_secret
	ENV["DINGTALK_APP_SECRET"]
end
```

**Step 4: Update `.env.example`**

Append:

```
# DingTalk enterprise app credentials (required for DingTalk collectors/publisher)
# DINGTALK_APP_KEY=your-app-key-here
# DINGTALK_APP_SECRET=your-app-secret-here
```

**Step 5: Run tests to verify they pass**

**Step 6: Commit**

```bash
git add lib/headway/config.rb test/headway/test_config.rb .env.example
git commit -m "feat: add DingTalk credential accessors to Config"
```

---

### Task 3: DingTalk Reports (日志) Collector

**Files:**
- Create: `lib/headway/collectors/dingtalk_reports.rb`
- Create: `test/headway/collectors/test_dingtalk_reports.rb`

**Step 1: Write the tests**

Create `test/headway/collectors/test_dingtalk_reports.rb`:

```ruby
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
```

**Step 2: Run tests to verify they fail**

**Step 3: Write implementation**

Create `lib/headway/collectors/dingtalk_reports.rb`:

```ruby
# DingTalk Reports (日志) collector. Reads employee daily/weekly work
# reports via the legacy DingTalk API. Reports are the primary progress
# data source — employees already submit these to their managers.

module Headway
	module Collectors
		class DingtalkReports
			def initialize( client:, interval_hours: 2, template_name: nil )
				@client = client
				@interval_hours = interval_hours
				@template_name = template_name
			end

			def collect
				reports = fetch_reports
				return [] if reports.empty?

				files = reports.map do | report |
					format_report( report )
				end

				[ { name: "Reports", files: files } ]
			end

		private

			def fetch_reports
				now = ( Time.now.to_f * 1000 ).to_i
				start = now - ( @interval_hours * 3600 * 1000 )

				all_reports = []
				cursor = 0

				loop do
					body = {
						start_time: start,
						end_time: now,
						cursor: cursor,
						size: 20
					}
					body[:template_name] = @template_name if @template_name

					result = @client.legacy_post( "/topapi/report/list", body: body )
					data = result.dig( "result", "data_list" ) || []
					all_reports.concat( data )

					break unless result.dig( "result", "has_more" )
					cursor += data.length
				end

				all_reports
			end

			def format_report( report )
				lines = []
				lines << "# #{report["template_name"]} — #{report["creator_name"]}"
				lines << ""
				lines << "- **Submitted**: #{format_time( report["create_time"] )}"
				lines << ""

				contents = report["contents"] || []
				contents.each do | field |
					lines << "## #{field["key"]}"
					lines << ""
					lines << field["value"].to_s
					lines << ""
				end

				if report["remark"] && !report["remark"].empty?
					lines << "## Remark"
					lines << ""
					lines << report["remark"]
				end

				filename = "#{format_date( report["create_time"] )}-#{sanitize( report["creator_name"] )}"
				{ filename: filename, content: lines.join( "\n" ) }
			end

			def format_time( ms )
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d %H:%M" )
			rescue
				ms.to_s
			end

			def format_date( ms )
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d" )
			rescue
				"unknown"
			end

			def sanitize( name )
				( name || "unknown" ).downcase.gsub( /\s+/, "-" ).gsub( /[^\w\-]/, "" )
			end
		end
	end
end
```

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add lib/headway/collectors/dingtalk_reports.rb test/headway/collectors/test_dingtalk_reports.rb
git commit -m "feat: DingTalk Reports (日志) collector"
```

---

### Task 4: DingTalk Todos Collector

**Files:**
- Create: `lib/headway/collectors/dingtalk_todos.rb`
- Create: `test/headway/collectors/test_dingtalk_todos.rb`

**Step 1: Write the tests**

Create `test/headway/collectors/test_dingtalk_todos.rb`. Use a `FakeDingTalkClient` that responds to `post`. Test:
- Collects tasks as single "Tasks" section
- Formats task content as structured markdown (subject, status, due, priority)
- Sorts by due date (earliest first)
- Returns empty for no tasks
- Handles tasks with nil due_date (sorted last)

**Step 2: Write implementation**

Create `lib/headway/collectors/dingtalk_todos.rb`:
- `POST /v1.0/todo/users/{unionId}/tasks/query` with `{ isDone: false }`
- Renders each task as markdown: `# subject`, status, due, assignee, priority, description
- Uses `format_date` for millisecond timestamps, `priority_label` for 10/20/30/40 levels

**Step 3: Run tests, verify pass, commit**

```bash
git add lib/headway/collectors/dingtalk_todos.rb test/headway/collectors/test_dingtalk_todos.rb
git commit -m "feat: DingTalk Todos collector"
```

---

### Task 5: DingTalk Meeting Notes Collector

**Files:**
- Create: `lib/headway/collectors/dingtalk_meetings.rb`
- Create: `test/headway/collectors/test_dingtalk_meetings.rb`

**Step 1: Write the tests**

Create `test/headway/collectors/test_dingtalk_meetings.rb`. Use a `FakeDingTalkClient`. Test:
- Collects meetings as single "Meeting Notes" section
- Formats meeting with title, date, transcript text
- Returns empty for no meetings
- Handles missing transcript gracefully

**Step 2: Write implementation**

Create `lib/headway/collectors/dingtalk_meetings.rb`:
- Two API calls per meeting: query recording details, then query transcript text
- Endpoint paths TBD from API Explorer — use placeholder paths like `GET /v1.0/conference/videoConferences/query` and `GET /v1.0/conference/videoConferences/{conferenceId}/recordings/transcripts`
- Renders as markdown: `# Meeting Title`, date, participants, full transcript

**Step 3: Run tests, verify pass, commit**

```bash
git add lib/headway/collectors/dingtalk_meetings.rb test/headway/collectors/test_dingtalk_meetings.rb
git commit -m "feat: DingTalk Meeting Notes collector"
```

---

### Task 6: DingTalk Doc Publisher

**Files:**
- Create: `lib/headway/publishers/dingtalk_doc.rb`
- Create: `test/headway/publishers/test_dingtalk_doc.rb`

**Step 1: Write the tests**

Create `test/headway/publishers/test_dingtalk_doc.rb`. Use a `FakeDingTalkClient` that records `post` calls. Test:
- Sends content to correct API path
- Sends operator_user_id in body
- Sends `sourceFormat: "markdown"` in body
- Raises on API error

**Step 2: Write implementation**

Create `lib/headway/publishers/dingtalk_doc.rb`:

```ruby
# DingTalk Doc publisher. Updates a single living DingTalk document
# in-place with the rendered Headway report. The document must already
# exist — the publisher overwrites its content each cycle.

module Headway
	module Publishers
		class DingtalkDoc
			def initialize( client:, space_id:, doc_id:, operator_user_id: )
				@client = client
				@space_id = space_id
				@doc_id = doc_id
				@operator_user_id = operator_user_id
			end

			def publish( content )
				@client.post(
					"/v1.0/doc/spaces/#{@space_id}/docs/#{@doc_id}/contents/update",
					body: {
						operatorId: @operator_user_id,
						content: content,
						sourceFormat: "markdown"
					}
				)
			end
		end
	end
end
```

**Step 3: Run tests, verify pass, commit**

```bash
git add lib/headway/publishers/dingtalk_doc.rb test/headway/publishers/test_dingtalk_doc.rb
git commit -m "feat: DingTalk Doc publisher — updates living document"
```

---

### Task 7: Runner Integration

**Files:**
- Modify: `lib/headway/runner.rb`

**Step 1: Add DingTalk case branches to `collect` method**

```ruby
def collect
	items = []
	@config.collectors.each do | c |
		case c["type"]
		when "local_files"
			items.concat Collectors::LocalFiles.new( c["path"] ).collect
		when "dingtalk_reports"
			items.concat Collectors::DingtalkReports.new(
				client: dingtalk_client,
				interval_hours: @config.interval_hours,
				template_name: c["template_name"]
			).collect
		when "dingtalk_todos"
			items.concat Collectors::DingtalkTodos.new(
				client: dingtalk_client,
				operator_user_id: c["operator_user_id"]
			).collect
		when "dingtalk_meetings"
			items.concat Collectors::DingtalkMeetings.new(
				client: dingtalk_client,
				interval_hours: @config.interval_hours
			).collect
		end
	end
	items
end
```

**Step 2: Add DingTalk case branch to `publish` method**

```ruby
when "dingtalk_doc"
	Publishers::DingtalkDoc.new(
		client: dingtalk_client,
		space_id: p["space_id"],
		doc_id: p["doc_id"],
		operator_user_id: p["operator_user_id"]
	).publish( report )
```

**Step 3: Add lazy `dingtalk_client` method**

```ruby
def dingtalk_client
	@dingtalk_client ||= DingTalk::Client.new(
		app_key: @config.dingtalk_app_key,
		app_secret: @config.dingtalk_app_secret
	)
end
```

**Step 4: Run full test suite, verify all pass, commit**

```bash
git add lib/headway/runner.rb
git commit -m "feat: Runner dispatches DingTalk collectors and publisher"
```

---

### Task 8: Config File Updates

**Files:**
- Modify: `config/headway.yml`

**Step 1: Add commented-out DingTalk entries**

```yaml
collectors:
  - type: local_files
    path: ./input
  # - type: dingtalk_reports
  #   template_name: "日报"
  # - type: dingtalk_todos
  #   operator_user_id: "your-user-id"
  # - type: dingtalk_meetings

publishers:
  - type: markdown_file
    path: ./output/report.md
  # - type: dingtalk_doc
  #   space_id: "your-space-id"
  #   doc_id: "your-doc-id"
  #   operator_user_id: "your-user-id"
```

**Step 2: Run full test suite, commit**

```bash
git add config/headway.yml
git commit -m "chore: add commented-out DingTalk config examples"
```

---

## Verification

1. Run full test suite: `bundle exec ruby -Ilib -Itest -e 'Dir["test/**/test_*.rb"].each { |f| require "./#{f}" }'` — all pass
2. With real DingTalk credentials: uncomment DingTalk entries in `config/headway.yml`, set `DINGTALK_APP_KEY` and `DINGTALK_APP_SECRET` in `.env`, run `ruby bin/headway run`
3. Check the target DingTalk Doc shows the rendered report
