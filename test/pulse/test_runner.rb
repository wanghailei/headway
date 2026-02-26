# Tests for Pulse::Runner. Verifies the full orchestration pipeline:
# collect items, synthesize via AI, render with template, and publish
# to output — using FakeAIClient from test_helper for isolation.

require "test_helper"
require "json"

class TestRunner < Minitest::Test
	def setup
		@dir = Dir.mktmpdir

		# Input folder with one item
		@input_dir = File.join( @dir, "input" )
		FileUtils.mkdir_p( File.join( @input_dir, "Project Alpha" ) )
		File.write(
			File.join( @input_dir, "Project Alpha", "2026-02-25-weekly.md" ),
			"Sprint 4 on track. Backend migration done."
		)

		# Output directory
		@output_dir = File.join( @dir, "output" )

		# Template
		@template_path = File.join( @dir, "report.md.erb" )
		File.write( @template_path, <<~ERB )
			# Pulse Report — <%= date %>

			<%= body %>
		ERB

		# Config
		@config_path = File.join( @dir, "pulse.yml" )
		File.write( @config_path, <<~YAML )
			ai:
			  base_url: http://localhost:9999/v1
			  model: gpt-4o
			collectors:
			  - type: local_files
			    path: #{@input_dir}
			publishers:
			  - type: markdown_file
			    path: #{@output_dir}
		YAML
	end

	def teardown
		FileUtils.rm_rf( @dir )
	end

	def test_run_produces_output_file
		# Two-stage: extraction returns JSON with one issue,
		# synthesis returns markdown status section.
		extraction_json = JSON.generate( [
			{ name: "Project Alpha", excerpts: [ "Sprint 4 on track. Backend migration done." ] }
		] )
		fake_ai = FakeAIClient.new( extraction_json, "### 🟢 Project Alpha\nOn track." )
		config = Pulse::Config.new( @config_path )

		runner = Pulse::Runner.new( config, ai_client: fake_ai, template_path: @template_path )
		runner.run

		files = Dir.glob( File.join( @output_dir, "RP.*.md" ) )
		assert_equal 1, files.length, "Should produce one timestamped report file"
		content = File.read( files.first )
		assert_includes content, "Pulse Report"
		assert_includes content, "Project Alpha"
	end

	def test_iterative_reporting_uses_previous_report
		# Create a previous report in output
		FileUtils.mkdir_p( @output_dir )
		File.write(
			File.join( @output_dir, "RP.26.02.24.10.md" ),
			"# Previous\n\n### 🟡 Project Alpha\n最后更新：2026-02-24\n进行中。"
		)

		extraction_json = JSON.generate( [
			{ name: "Project Alpha", excerpts: [ "Sprint 4 on track." ] }
		] )
		fake_ai = FakeAIClient.new( extraction_json, "### 🟢 Project Alpha\nDone." )
		config = Pulse::Config.new( @config_path )

		runner = Pulse::Runner.new( config, ai_client: fake_ai, template_path: @template_path )
		runner.run

		# Extraction prompt should include previous report
		extraction_prompt = fake_ai.calls[0][:prompt]
		assert_includes extraction_prompt, "上期进度报告"
		assert_includes extraction_prompt, "Project Alpha"
	end
end
