# Tests for Headway::Synthesizer two-stage pipeline. Stage 1 extracts
# issues from collected items. Stage 2 synthesizes a status section for
# each issue. Uses FakeAIClient from test_helper to simulate sequential
# AI responses (extraction JSON → synthesis markdown).

require "test_helper"
require "json"

class TestSynthesizer < Minitest::Test
	def test_extraction_prompt_includes_all_items
		items = [
			{
				name: "Project Alpha",
				files: [
					{ filename: "2026-02-25-weekly.md", content: "Sprint 4 on track." }
				]
			}
		]

		extraction_json = JSON.generate( [
			{ name: "Sprint 4", excerpts: [ "Sprint 4 on track." ] }
		] )
		fake = FakeAIClient.new( extraction_json, "### Sprint 4\nOn track." )
		Headway::Synthesizer.new( fake ).synthesize( items )

		extraction_prompt = fake.calls[0][:prompt]
		assert_includes extraction_prompt, "Project Alpha"
		assert_includes extraction_prompt, "Sprint 4 on track."
	end

	def test_synthesizes_each_extracted_issue
		items = [
			{ name: "Reports", files: [ { filename: "alice.md", content: "API done. Tests pending." } ] }
		]

		extraction_json = JSON.generate( [
			{ name: "API Integration", excerpts: [ "API done." ] },
			{ name: "Testing", excerpts: [ "Tests pending." ] }
		] )
		fake = FakeAIClient.new(
			extraction_json,
			"### 🟢 API Integration\nCompleted.",
			"### 🟡 Testing\nPending."
		)
		result = Headway::Synthesizer.new( fake ).synthesize( items )

		# 1 extraction + 2 synthesis calls
		assert_equal 3, fake.calls.length
		assert_includes result, "API Integration"
		assert_includes result, "Testing"
	end

	def test_returns_joined_synthesis_sections
		items = [
			{ name: "Updates", files: [ { filename: "data.md", content: "stuff" } ] }
		]

		extraction_json = JSON.generate( [
			{ name: "Issue A", excerpts: [ "detail a" ] },
			{ name: "Issue B", excerpts: [ "detail b" ] }
		] )
		fake = FakeAIClient.new( extraction_json, "Section A", "Section B" )
		result = Headway::Synthesizer.new( fake ).synthesize( items )

		assert_equal "Section A\n\nSection B", result
	end

	def test_synthesis_prompt_includes_issue_name_and_excerpts
		items = [
			{ name: "Reports", files: [ { filename: "bob.md", content: "Deployed v2." } ] }
		]

		extraction_json = JSON.generate( [
			{ name: "Deployment", excerpts: [ "Deployed v2.", "Rollback plan ready." ] }
		] )
		fake = FakeAIClient.new( extraction_json, "### Deployment\nDone." )
		Headway::Synthesizer.new( fake ).synthesize( items )

		synth_prompt = fake.calls[1][:prompt]
		assert_includes synth_prompt, "Deployment"
		assert_includes synth_prompt, "Deployed v2."
		assert_includes synth_prompt, "Rollback plan ready."
	end

	def test_falls_back_on_invalid_extraction_json
		items = [
			{ name: "Reports", files: [ { filename: "update.md", content: "progress" } ] }
		]

		fake = FakeAIClient.new( "not valid json at all", "### General Update\nSummary." )
		result = Headway::Synthesizer.new( fake ).synthesize( items )

		# Fallback creates one "General Update" issue → 1 extraction + 1 synthesis
		assert_equal 2, fake.calls.length
		assert_includes fake.calls[1][:prompt], "General Update"
		assert_equal "### General Update\nSummary.", result
	end

	def test_strips_code_fences_from_extraction_response
		items = [
			{ name: "Reports", files: [ { filename: "update.md", content: "data" } ] }
		]

		wrapped = "```json\n[{\"name\": \"Bug Fix\", \"excerpts\": [\"data\"]}]\n```"
		fake = FakeAIClient.new( wrapped, "### Bug Fix\nFixed." )
		result = Headway::Synthesizer.new( fake ).synthesize( items )

		assert_equal 2, fake.calls.length
		assert_includes result, "Bug Fix"
	end

	def test_returns_empty_string_for_no_items
		fake = FakeAIClient.new( "should not be called" )
		result = Headway::Synthesizer.new( fake ).synthesize( [] )

		assert_equal "", result
		assert_equal 0, fake.calls.length
	end

	def test_extraction_uses_extract_system_prompt
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		extraction_json = JSON.generate( [ { name: "X", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Headway::Synthesizer.new( fake ).synthesize( items )

		extract_system = fake.calls[0][:system]
		assert_includes extract_system, "identify every distinct issue"
		assert_includes extract_system, "JSON"
	end

	def test_synthesis_uses_synthesis_system_prompt
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		extraction_json = JSON.generate( [ { name: "X", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Headway::Synthesizer.new( fake ).synthesize( items )

		synth_system = fake.calls[1][:system]
		assert_includes synth_system, "status indicator"
		assert_includes synth_system, "🟢"
		assert_includes synth_system, "🔴"
	end

	def test_handles_multiple_items_from_different_sources
		items = [
			{
				name: "Local Files",
				files: [ { filename: "project-x/update.md", content: "Design review done." } ]
			},
			{
				name: "Reports",
				files: [
					{ filename: "2026-02-25-alice", content: "Finished API for Project X." },
					{ filename: "2026-02-25-bob", content: "Started testing Project Y." }
				]
			}
		]

		extraction_json = JSON.generate( [
			{ name: "Project X", excerpts: [ "Design review done.", "Finished API for Project X." ] },
			{ name: "Project Y", excerpts: [ "Started testing Project Y." ] }
		] )
		fake = FakeAIClient.new(
			extraction_json,
			"### 🟢 Project X\nOn track.",
			"### 🟡 Project Y\nJust started."
		)
		result = Headway::Synthesizer.new( fake ).synthesize( items )

		# 1 extraction + 2 synthesis = 3 calls
		assert_equal 3, fake.calls.length
		assert_includes result, "Project X"
		assert_includes result, "Project Y"

		# Extraction prompt should include data from both sources
		extraction_prompt = fake.calls[0][:prompt]
		assert_includes extraction_prompt, "Local Files"
		assert_includes extraction_prompt, "Reports"
		assert_includes extraction_prompt, "Design review done."
		assert_includes extraction_prompt, "Finished API for Project X."
	end
end
