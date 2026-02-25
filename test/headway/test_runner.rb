# Tests for Headway::Runner. Verifies the full orchestration pipeline:
# collect items, synthesize via AI, render with template, and publish
# to output — using a fake AI client for isolation.

require "test_helper"
require "headway/runner"

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

		# Output path
		@output_path = File.join( @dir, "output", "report.md" )

		# Template
		@template_path = File.join( @dir, "report.md.erb" )
		File.write( @template_path, <<~ERB )
			# Headway Report — <%= date %>

			<%= body %>
		ERB

		# Config
		@config_path = File.join( @dir, "headway.yml" )
		File.write( @config_path, <<~YAML )
			ai:
			  base_url: http://localhost:9999/v1
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
		FileUtils.rm_rf( @dir )
	end

	def test_run_produces_output_file
		fake_ai = FakeAIClient.new( "### Project Alpha\nOn track." )
		config = Headway::Config.new( @config_path )

		runner = Headway::Runner.new( config, ai_client: fake_ai, template_path: @template_path )
		runner.run

		assert File.exist?( @output_path ), "Report file should exist at #{@output_path}"
		content = File.read( @output_path )
		assert_includes content, "Headway Report"
		assert_includes content, "Project Alpha"
	end
end

# Reuse fake client — guard against double-definition when running
# multiple test files together (test_synthesizer.rb defines the same class).
unless defined?( FakeAIClient )
	class FakeAIClient
		attr_reader :last_prompt, :last_system

		def initialize( response )
			@response = response
		end

		def chat( prompt, system: nil )
			@last_prompt = prompt
			@last_system = system
			@response
		end
	end
end
