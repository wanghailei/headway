# Tests for Headway::Synthesizer. Verifies prompt construction from
# collected items, AI response passthrough, and system prompt content
# using a fake AI client stub.

require "test_helper"
require "headway/synthesizer"

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

		fake_client = FakeAIClient.new( "### Project Alpha\nOn track." )
		synthesizer = Headway::Synthesizer.new( fake_client )
		synthesizer.synthesize( items )

		assert_includes fake_client.last_prompt, "Project Alpha"
		assert_includes fake_client.last_prompt, "Sprint 4 on track."
	end

	def test_returns_ai_response_as_report_body
		items = [
			{ name: "Project Alpha", files: [ { filename: "update.md", content: "ok" } ] }
		]

		fake_client = FakeAIClient.new( "### Project Alpha\nAll good." )
		synthesizer = Headway::Synthesizer.new( fake_client )
		result = synthesizer.synthesize( items )

		assert_equal "### Project Alpha\nAll good.", result
	end

	def test_system_prompt_describes_headway_role
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		fake_client = FakeAIClient.new( "ok" )
		synthesizer = Headway::Synthesizer.new( fake_client )
		synthesizer.synthesize( items )

		assert_includes fake_client.last_system, "progress oversight"
		assert_includes fake_client.last_system, "🟢"
		assert_includes fake_client.last_system, "🔴"
	end
end
