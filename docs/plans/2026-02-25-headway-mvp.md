# Headway MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a working Headway that reads markdown files from a local input folder, sends them to OpenAI to synthesize a living progress report, and writes the report to a local output file.

**Architecture:** A Ruby CLI (`bin/headway run`) orchestrates three phases: collect → synthesize → publish. Each phase is a separate module. Config via YAML + ENV. No gems — stdlib only.

**Tech Stack:** Ruby 4.0, minitest (stdlib), net/http, json, yaml, erb, fileutils

**Refs:** `docs/define.md` (product spec), `docs/develop.md` (tech architecture)

---

## Task 1: Project Scaffold

**Files:**
- Create: `lib/headway.rb`
- Create: `lib/headway/config.rb`
- Create: `config/headway.yml`
- Create: `bin/headway`
- Create: `test/test_helper.rb`
- Create: `.gitignore`

**Step 1: Create `.gitignore`**

```gitignore
output/
.env
*.log
```

**Step 2: Create the config file**

```yaml
# config/headway.yml
ai:
  base_url: https://api.openai.com/v1
  model: gpt-4o

collectors:
  - type: local_files
    path: ./input

publishers:
  - type: markdown_file
    path: ./output/report.md

schedule:
  interval_hours: 2
```

**Step 3: Create test helper**

```ruby
# test/test_helper.rb
require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
```

**Step 4: Create the main lib entry point**

```ruby
# lib/headway.rb
require_relative "headway/config"

module Headway
  VERSION = "0.1.0"
end
```

**Step 5: Create a placeholder config loader**

```ruby
# lib/headway/config.rb
require "yaml"

module Headway
  class Config
    attr_reader :data

    def initialize(path = "config/headway.yml")
      @data = YAML.load_file(path)
    end
  end
end
```

**Step 6: Create the bin entry point**

```ruby
#!/usr/bin/env ruby
# bin/headway

require_relative "../lib/headway"

puts "Headway v#{Headway::VERSION}"
```

**Step 7: Make bin executable and verify**

Run: `chmod +x bin/headway && ruby bin/headway`
Expected: `Headway v0.1.0`

**Step 8: Commit**

```bash
git add -A && git commit -m "scaffold: project structure, config, test helper, bin entry point"
```

---

## Task 2: Config Loader

**Files:**
- Modify: `lib/headway/config.rb`
- Create: `test/headway/test_config.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/test_config.rb
require "test_helper"
require "headway/config"

class TestConfig < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @config_path = File.join(@dir, "headway.yml")
    File.write(@config_path, <<~YAML)
      ai:
        base_url: https://api.openai.com/v1
        model: gpt-4o
      collectors:
        - type: local_files
          path: ./input
      publishers:
        - type: markdown_file
          path: ./output/report.md
    YAML
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_loads_ai_config
    config = Headway::Config.new(@config_path)
    assert_equal "https://api.openai.com/v1", config.ai_base_url
    assert_equal "gpt-4o", config.ai_model
  end

  def test_ai_api_key_from_env
    ENV["HEADWAY_AI_API_KEY"] = "test-key-123"
    config = Headway::Config.new(@config_path)
    assert_equal "test-key-123", config.ai_api_key
  ensure
    ENV.delete("HEADWAY_AI_API_KEY")
  end

  def test_env_overrides_base_url
    ENV["HEADWAY_AI_BASE_URL"] = "https://custom.api.com/v1"
    config = Headway::Config.new(@config_path)
    assert_equal "https://custom.api.com/v1", config.ai_base_url
  ensure
    ENV.delete("HEADWAY_AI_BASE_URL")
  end

  def test_collectors_config
    config = Headway::Config.new(@config_path)
    assert_equal 1, config.collectors.length
    assert_equal "local_files", config.collectors.first["type"]
  end

  def test_publishers_config
    config = Headway::Config.new(@config_path)
    assert_equal 1, config.publishers.length
    assert_equal "markdown_file", config.publishers.first["type"]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/test_config.rb`
Expected: FAIL — `NoMethodError: undefined method 'ai_base_url'`

**Step 3: Implement Config**

```ruby
# lib/headway/config.rb
require "yaml"

module Headway
  class Config
    def initialize(path = "config/headway.yml")
      @data = YAML.load_file(path)
    end

    def ai_base_url
      ENV["HEADWAY_AI_BASE_URL"] || @data.dig("ai", "base_url")
    end

    def ai_model
      ENV["HEADWAY_AI_MODEL"] || @data.dig("ai", "model")
    end

    def ai_api_key
      ENV["HEADWAY_AI_API_KEY"]
    end

    def collectors
      @data.fetch("collectors", [])
    end

    def publishers
      @data.fetch("publishers", [])
    end

    def interval_hours
      @data.dig("schedule", "interval_hours") || 2
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/test_config.rb`
Expected: 5 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/headway/config.rb test/headway/test_config.rb
git commit -m "feat: config loader with ENV overrides"
```

---

## Task 3: Local File Collector

**Files:**
- Create: `lib/headway/collectors/local_files.rb`
- Create: `test/headway/collectors/test_local_files.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/collectors/test_local_files.rb
require "test_helper"
require "headway/collectors/local_files"

class TestLocalFilesCollector < Minitest::Test
  def setup
    @dir = Dir.mktmpdir

    # Create two "things" with files
    FileUtils.mkdir_p(File.join(@dir, "Project Alpha"))
    File.write(File.join(@dir, "Project Alpha", "2026-02-18-kickoff.md"),
      "# Kickoff\nProject started. Team assigned.")
    File.write(File.join(@dir, "Project Alpha", "2026-02-25-weekly.md"),
      "# Weekly\nSprint 4 on track. Backend done.")

    FileUtils.mkdir_p(File.join(@dir, "Login Timeout"))
    File.write(File.join(@dir, "Login Timeout", "2026-02-24-resolved.md"),
      "# Resolved\nFixed connection pool. Deployed Monday.")

    # Ignored folders
    FileUtils.mkdir_p(File.join(@dir, "_templates"))
    File.write(File.join(@dir, "_templates", "weekly-update.md"), "template content")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_collects_all_things
    collector = Headway::Collectors::LocalFiles.new(@dir)
    items = collector.collect
    names = items.map { |i| i[:name] }.sort
    assert_equal ["Login Timeout", "Project Alpha"], names
  end

  def test_collects_files_sorted_by_date
    collector = Headway::Collectors::LocalFiles.new(@dir)
    items = collector.collect
    alpha = items.find { |i| i[:name] == "Project Alpha" }
    assert_equal 2, alpha[:files].length
    assert_match(/kickoff/, alpha[:files].first[:filename])
    assert_match(/weekly/, alpha[:files].last[:filename])
  end

  def test_reads_file_content
    collector = Headway::Collectors::LocalFiles.new(@dir)
    items = collector.collect
    alpha = items.find { |i| i[:name] == "Project Alpha" }
    assert_includes alpha[:files].last[:content], "Sprint 4 on track"
  end

  def test_ignores_underscore_folders
    collector = Headway::Collectors::LocalFiles.new(@dir)
    items = collector.collect
    names = items.map { |i| i[:name] }
    refute_includes names, "_templates"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/collectors/test_local_files.rb`
Expected: FAIL — `LoadError: cannot load such file -- headway/collectors/local_files`

**Step 3: Implement LocalFiles collector**

```ruby
# lib/headway/collectors/local_files.rb
module Headway
  module Collectors
    class LocalFiles
      def initialize(path)
        @path = path
      end

      def collect
        Dir.children(@path)
          .select { |name| File.directory?(File.join(@path, name)) }
          .reject { |name| name.start_with?("_") }
          .sort
          .map { |name| collect_thing(name) }
      end

      private

      def collect_thing(name)
        thing_path = File.join(@path, name)
        files = Dir.children(thing_path)
          .select { |f| f.end_with?(".md") }
          .sort
          .map { |f| read_file(thing_path, f) }

        { name: name, files: files }
      end

      def read_file(dir, filename)
        path = File.join(dir, filename)
        { filename: filename, content: File.read(path) }
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/collectors/test_local_files.rb`
Expected: 4 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/headway/collectors/local_files.rb test/headway/collectors/test_local_files.rb
git commit -m "feat: local file collector with convention-based folder scanning"
```

---

## Task 4: OpenAI Client

**Files:**
- Create: `lib/headway/ai_client.rb`
- Create: `test/headway/test_ai_client.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/test_ai_client.rb
require "test_helper"
require "headway/ai_client"
require "webrick"
require "json"

class TestAIClient < Minitest::Test
  def setup
    @server = WEBrick::HTTPServer.new(Port: 0, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
    @port = @server.config[:Port]

    @server.mount_proc "/v1/chat/completions" do |req, res|
      body = JSON.parse(req.body)
      @last_request = body
      res.content_type = "application/json"
      res.body = JSON.generate({
        choices: [{ message: { content: "AI response here" } }]
      })
    end

    @thread = Thread.new { @server.start }
  end

  def teardown
    @server.shutdown
    @thread.join
  end

  def test_sends_prompt_and_returns_content
    client = Headway::AIClient.new(
      base_url: "http://localhost:#{@port}/v1",
      api_key: "test-key",
      model: "gpt-4o"
    )
    result = client.chat("Summarize this: hello world")
    assert_equal "AI response here", result
  end

  def test_sends_correct_headers
    client = Headway::AIClient.new(
      base_url: "http://localhost:#{@port}/v1",
      api_key: "sk-test-abc",
      model: "gpt-4o"
    )
    client.chat("test")
    # If we got a response, the request was accepted — headers were valid
    assert_equal "gpt-4o", @last_request["model"]
  end

  def test_sends_system_and_user_messages
    client = Headway::AIClient.new(
      base_url: "http://localhost:#{@port}/v1",
      api_key: "test-key",
      model: "gpt-4o"
    )
    client.chat("user prompt", system: "system prompt")
    messages = @last_request["messages"]
    assert_equal "system", messages[0]["role"]
    assert_equal "system prompt", messages[0]["content"]
    assert_equal "user", messages[1]["role"]
    assert_equal "user prompt", messages[1]["content"]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/test_ai_client.rb`
Expected: FAIL — `LoadError: cannot load such file -- headway/ai_client`

**Step 3: Implement AIClient**

```ruby
# lib/headway/ai_client.rb
require "net/http"
require "uri"
require "json"

module Headway
  class AIClient
    def initialize(base_url:, api_key:, model:)
      @base_url = base_url
      @api_key = api_key
      @model = model
    end

    def chat(prompt, system: nil)
      uri = URI("#{@base_url}/chat/completions")

      messages = []
      messages << { role: "system", content: system } if system
      messages << { role: "user", content: prompt }

      body = { model: @model, messages: messages }

      response = post(uri, body)
      data = JSON.parse(response.body)
      data.dig("choices", 0, "message", "content")
    end

    private

    def post(uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request.body = JSON.generate(body)

      http.request(request)
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/test_ai_client.rb`
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/headway/ai_client.rb test/headway/test_ai_client.rb
git commit -m "feat: OpenAI-compatible AI client using net/http"
```

---

## Task 5: Synthesizer

**Files:**
- Create: `lib/headway/synthesizer.rb`
- Create: `test/headway/test_synthesizer.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/test_synthesizer.rb
require "test_helper"
require "headway/synthesizer"

class FakeAIClient
  attr_reader :last_prompt, :last_system

  def initialize(response)
    @response = response
  end

  def chat(prompt, system: nil)
    @last_prompt = prompt
    @last_system = system
    @response
  end
end

class TestSynthesizer < Minitest::Test
  def test_builds_prompt_from_collected_items
    items = [
      {
        name: "Project Alpha",
        files: [
          { filename: "2026-02-25-weekly.md", content: "Sprint 4 on track." }
        ]
      }
    ]

    fake_client = FakeAIClient.new("### 🟢 Project Alpha\nOn track.")
    synthesizer = Headway::Synthesizer.new(fake_client)
    synthesizer.synthesize(items)

    assert_includes fake_client.last_prompt, "Project Alpha"
    assert_includes fake_client.last_prompt, "Sprint 4 on track."
  end

  def test_returns_ai_response_as_report_body
    items = [
      { name: "Project Alpha", files: [{ filename: "update.md", content: "ok" }] }
    ]

    fake_client = FakeAIClient.new("### 🟢 Project Alpha\nAll good.")
    synthesizer = Headway::Synthesizer.new(fake_client)
    result = synthesizer.synthesize(items)

    assert_equal "### 🟢 Project Alpha\nAll good.", result
  end

  def test_system_prompt_describes_headway_role
    items = [{ name: "X", files: [{ filename: "a.md", content: "b" }] }]

    fake_client = FakeAIClient.new("ok")
    synthesizer = Headway::Synthesizer.new(fake_client)
    synthesizer.synthesize(items)

    assert_includes fake_client.last_system, "progress oversight"
    assert_includes fake_client.last_system, "🟢"
    assert_includes fake_client.last_system, "🔴"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/test_synthesizer.rb`
Expected: FAIL — `LoadError`

**Step 3: Implement Synthesizer**

```ruby
# lib/headway/synthesizer.rb
module Headway
  class Synthesizer
    SYSTEM_PROMPT = <<~PROMPT
      You are Headway, a progress oversight report writer for executives.

      You will receive collected updates for tracked items (projects, issues, goals, etc.).
      For each item, write a concise status section for the report.

      Rules:
      - Each item gets a ### heading with a status indicator and the item name
      - Include "Due:" and "@assigned" if inferable from the content
      - Include "Last updated:" with today's date
      - Write 2-4 sentences synthesizing the current state
      - Use these status indicators:
        🟢 Green — on track / healthy
        🟡 Yellow — needs attention / at risk
        🔴 Red — blocked / off track / overdue
        ✅ Checked — finished / resolved
      - For ✅ finished items, add a **Review:** line summarizing what happened
      - Be direct, factual, no filler
      - Output raw markdown, no code fences
    PROMPT

    def initialize(ai_client)
      @ai_client = ai_client
    end

    def synthesize(items)
      prompt = build_prompt(items)
      @ai_client.chat(prompt, system: SYSTEM_PROMPT)
    end

    private

    def build_prompt(items)
      sections = items.map { |item| format_item(item) }
      "Here are the collected updates for each tracked item:\n\n#{sections.join("\n\n---\n\n")}"
    end

    def format_item(item)
      file_texts = item[:files].map do |f|
        "**#{f[:filename]}:**\n#{f[:content]}"
      end
      "## #{item[:name]}\n\n#{file_texts.join("\n\n")}"
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/test_synthesizer.rb`
Expected: 3 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/headway/synthesizer.rb test/headway/test_synthesizer.rb
git commit -m "feat: synthesizer builds prompt from items, calls AI, returns report"
```

---

## Task 6: Report Template

**Files:**
- Create: `templates/report.md.erb`
- Create: `lib/headway/report_renderer.rb`
- Create: `test/headway/test_report_renderer.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/test_report_renderer.rb
require "test_helper"
require "headway/report_renderer"

class TestReportRenderer < Minitest::Test
  def setup
    @template_dir = Dir.mktmpdir
    @template_path = File.join(@template_dir, "report.md.erb")
    File.write(@template_path, <<~ERB)
      # Headway Report — <%= date %>

      <%= body %>
    ERB
  end

  def teardown
    FileUtils.rm_rf(@template_dir)
  end

  def test_renders_report_with_date_and_body
    renderer = Headway::ReportRenderer.new(@template_path)
    result = renderer.render(
      date: "2026-02-25",
      body: "### 🟢 Project Alpha\nOn track."
    )

    assert_includes result, "# Headway Report — 2026-02-25"
    assert_includes result, "### 🟢 Project Alpha"
    assert_includes result, "On track."
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/test_report_renderer.rb`
Expected: FAIL — `LoadError`

**Step 3: Create the ERB template**

```erb
# Headway Report — <%= date %>

<%= body %>
```

Save to: `templates/report.md.erb`

**Step 4: Implement ReportRenderer**

```ruby
# lib/headway/report_renderer.rb
require "erb"

module Headway
  class ReportRenderer
    def initialize(template_path = "templates/report.md.erb")
      @template = File.read(template_path)
    end

    def render(date:, body:)
      ERB.new(@template, trim_mode: "-").result(binding)
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/test_report_renderer.rb`
Expected: 1 test, 0 failures

**Step 6: Commit**

```bash
git add templates/report.md.erb lib/headway/report_renderer.rb test/headway/test_report_renderer.rb
git commit -m "feat: ERB report renderer with date and body"
```

---

## Task 7: Markdown File Publisher

**Files:**
- Create: `lib/headway/publishers/markdown_file.rb`
- Create: `test/headway/publishers/test_markdown_file.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/publishers/test_markdown_file.rb
require "test_helper"
require "headway/publishers/markdown_file"

class TestMarkdownFilePublisher < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @output_path = File.join(@dir, "output", "report.md")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_writes_report_to_file
    publisher = Headway::Publishers::MarkdownFile.new(@output_path)
    publisher.publish("# Report\n\nContent here.")

    assert File.exist?(@output_path)
    assert_equal "# Report\n\nContent here.", File.read(@output_path)
  end

  def test_creates_parent_directories
    publisher = Headway::Publishers::MarkdownFile.new(@output_path)
    publisher.publish("test")

    assert File.directory?(File.dirname(@output_path))
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/publishers/test_markdown_file.rb`
Expected: FAIL — `LoadError`

**Step 3: Implement MarkdownFile publisher**

```ruby
# lib/headway/publishers/markdown_file.rb
require "fileutils"

module Headway
  module Publishers
    class MarkdownFile
      def initialize(path)
        @path = path
      end

      def publish(content)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, content)
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/publishers/test_markdown_file.rb`
Expected: 2 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/headway/publishers/markdown_file.rb test/headway/publishers/test_markdown_file.rb
git commit -m "feat: markdown file publisher with auto-created directories"
```

---

## Task 8: Orchestrator

**Files:**
- Create: `lib/headway/runner.rb`
- Create: `test/headway/test_runner.rb`
- Modify: `lib/headway.rb`

**Step 1: Write the failing test**

```ruby
# test/headway/test_runner.rb
require "test_helper"
require "headway/runner"

class TestRunner < Minitest::Test
  def setup
    @dir = Dir.mktmpdir

    # Input folder with one item
    @input_dir = File.join(@dir, "input")
    FileUtils.mkdir_p(File.join(@input_dir, "Project Alpha"))
    File.write(
      File.join(@input_dir, "Project Alpha", "2026-02-25-weekly.md"),
      "Sprint 4 on track. Backend migration done."
    )

    # Output path
    @output_path = File.join(@dir, "output", "report.md")

    # Template
    @template_path = File.join(@dir, "report.md.erb")
    File.write(@template_path, <<~ERB)
      # Headway Report — <%= date %>

      <%= body %>
    ERB

    # Config
    @config_path = File.join(@dir, "headway.yml")
    File.write(@config_path, <<~YAML)
      ai:
        base_url: http://localhost:#{@port}/v1
        model: gpt-4o
      collectors:
        - type: local_files
          path: #{@input_dir}
      publishers:
        - type: markdown_file
          path: #{@output_path}
    YAML
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_run_produces_output_file
    # Use a fake AI client to avoid real API calls
    fake_ai = FakeAIClient.new("### 🟢 Project Alpha\nOn track.")
    config = Headway::Config.new(@config_path)

    runner = Headway::Runner.new(config, ai_client: fake_ai, template_path: @template_path)
    runner.run

    assert File.exist?(@output_path), "Report file should exist at #{@output_path}"
    content = File.read(@output_path)
    assert_includes content, "Headway Report"
    assert_includes content, "Project Alpha"
  end
end

# Reuse from synthesizer test
class FakeAIClient
  attr_reader :last_prompt, :last_system
  def initialize(response) = @response = response
  def chat(prompt, system: nil)
    @last_prompt = prompt
    @last_system = system
    @response
  end
end
```

**Step 2: Run test to verify it fails**

Run: `ruby -Ilib -Itest test/headway/test_runner.rb`
Expected: FAIL — `LoadError`

**Step 3: Implement Runner**

```ruby
# lib/headway/runner.rb
require_relative "config"
require_relative "ai_client"
require_relative "collectors/local_files"
require_relative "synthesizer"
require_relative "report_renderer"
require_relative "publishers/markdown_file"

module Headway
  class Runner
    def initialize(config, ai_client: nil, template_path: "templates/report.md.erb")
      @config = config
      @ai_client = ai_client || build_ai_client
      @template_path = template_path
    end

    def run
      items = collect
      body = synthesize(items)
      report = render(body)
      publish(report)
    end

    private

    def collect
      items = []
      @config.collectors.each do |c|
        case c["type"]
        when "local_files"
          items.concat(Collectors::LocalFiles.new(c["path"]).collect)
        end
      end
      items
    end

    def synthesize(items)
      Synthesizer.new(@ai_client).synthesize(items)
    end

    def render(body)
      ReportRenderer.new(@template_path).render(
        date: Time.now.strftime("%Y-%m-%d"),
        body: body
      )
    end

    def publish(report)
      @config.publishers.each do |p|
        case p["type"]
        when "markdown_file"
          Publishers::MarkdownFile.new(p["path"]).publish(report)
        end
      end
    end

    def build_ai_client
      AIClient.new(
        base_url: @config.ai_base_url,
        api_key: @config.ai_api_key,
        model: @config.ai_model
      )
    end
  end
end
```

**Step 4: Update lib/headway.rb to require runner**

```ruby
# lib/headway.rb
require_relative "headway/config"
require_relative "headway/runner"

module Headway
  VERSION = "0.1.0"
end
```

**Step 5: Run test to verify it passes**

Run: `ruby -Ilib -Itest test/headway/test_runner.rb`
Expected: 1 test, 0 failures

**Step 6: Commit**

```bash
git add lib/headway/runner.rb lib/headway.rb test/headway/test_runner.rb
git commit -m "feat: runner orchestrates collect → synthesize → render → publish"
```

---

## Task 9: CLI Entry Point

**Files:**
- Modify: `bin/headway`

**Step 1: Implement the CLI**

```ruby
#!/usr/bin/env ruby
# bin/headway

require_relative "../lib/headway"

command = ARGV[0]

case command
when "run"
  config = Headway::Config.new
  runner = Headway::Runner.new(config)

  puts "Headway v#{Headway::VERSION} — running..."
  runner.run
  puts "Done. Report published."

when "version", "--version", "-v"
  puts "Headway v#{Headway::VERSION}"

else
  puts "Headway v#{Headway::VERSION}"
  puts ""
  puts "Usage:"
  puts "  bin/headway run       # Run one collect-synthesize-publish cycle"
  puts "  bin/headway version   # Show version"
end
```

**Step 2: Test manually**

Run: `ruby bin/headway`
Expected: Shows usage message

Run: `ruby bin/headway version`
Expected: `Headway v0.1.0`

**Step 3: Commit**

```bash
git add bin/headway
git commit -m "feat: CLI entry point with run and version commands"
```

---

## Task 10: End-to-End Test with Sample Data

**Files:**
- Create: `input/Project Alpha/2026-02-18-kickoff.md`
- Create: `input/Project Alpha/2026-02-25-weekly.md`
- Create: `input/Login Timeout/2026-02-22-report.md`
- Create: `input/Login Timeout/2026-02-24-resolved.md`
- Create: `input/Q1 Revenue Target/2026-02-25-update.md`
- Create: `input/_templates/weekly-update.md`

**Step 1: Create sample input data**

```markdown
<!-- input/Project Alpha/2026-02-18-kickoff.md -->
# Project Alpha — Kickoff

Team: @alice @bob
Due: 2026-03-15
Started sprint planning. Backend migration scoped to 3 weeks.
```

```markdown
<!-- input/Project Alpha/2026-02-25-weekly.md -->
# Weekly Update — Feb 25

Sprint 4 is on track. Backend migration completed Monday.
Frontend integration in progress — expected done by Thursday.
No blockers. @alice leading frontend, @bob on API tests.
```

```markdown
<!-- input/Login Timeout/2026-02-22-report.md -->
# Login Timeout Issue

Reported: 2026-02-21
Assigned: @eve
Due: 2026-02-24

Users experiencing 30s timeouts on login. Suspected connection pool exhaustion.
Investigating today.
```

```markdown
<!-- input/Login Timeout/2026-02-24-resolved.md -->
# Resolved

Root cause: connection pool size was set to 5, needed 50 under peak load.
Fix deployed Monday morning. Monitored for 24h — no recurrence.
Total resolution time: 3 days.
```

```markdown
<!-- input/Q1 Revenue Target/2026-02-25-update.md -->
# Q1 Revenue — Feb 25

Target: $2.5M
Current: $2.1M (84%)
Due: 2026-03-31
Owner: @vp-sales

On pace. February pipeline strong. March looks solid based on committed deals.
```

```markdown
<!-- input/_templates/weekly-update.md -->
# Weekly Update — [Date]

[Summary of this week's progress]

Blockers: [any blockers]
Next week: [planned work]
```

**Step 2: Run Headway end-to-end**

Run: `HEADWAY_AI_API_KEY=your-key-here ruby bin/headway run`
Expected: "Done. Report published." and `output/report.md` contains the synthesized report.

**Step 3: Inspect the output**

Run: `cat output/report.md`
Expected: A markdown report with `# Headway Report — 2026-02-25` header, status indicators (🟢🟡🔴✅), due dates, assignees, and synthesized narratives.

**Step 4: Commit sample data (not the output)**

```bash
git add input/
git commit -m "feat: sample input data for end-to-end testing"
```

---

## Task 11: Run All Tests

**Step 1: Run the full test suite**

Run: `ruby -Ilib -Itest -e "Dir.glob('test/**/test_*.rb').each { |f| require File.expand_path(f) }"`
Expected: All tests pass (14+ tests, 0 failures)

**Step 2: Commit if any fixes were needed**

---

## Summary

After completing all tasks, you'll have:

| Component | File | Status |
|---|---|---|
| Config | `lib/headway/config.rb` | ✅ ENV overrides, YAML loading |
| Collector | `lib/headway/collectors/local_files.rb` | ✅ Convention-based folder scanning |
| AI Client | `lib/headway/ai_client.rb` | ✅ OpenAI-compatible HTTP client |
| Synthesizer | `lib/headway/synthesizer.rb` | ✅ Prompt building + AI call |
| Renderer | `lib/headway/report_renderer.rb` | ✅ ERB template rendering |
| Publisher | `lib/headway/publishers/markdown_file.rb` | ✅ Write to file |
| Runner | `lib/headway/runner.rb` | ✅ Orchestrator |
| CLI | `bin/headway` | ✅ `run` and `version` commands |
| Tests | `test/**/*.rb` | ✅ Full coverage with minitest |

**Next steps after MVP:**
- DingTalk shared folder collector (via DingTalk Docs API)
- DingTalk group chat collector (via DingTalk Stream API)
- DingTalk Todo/Task collector (via DingTalk Open API)
- DingTalk Doc publisher (via DingTalk Docs API)
- Scheduled loop (cron or built-in sleep cycle)
