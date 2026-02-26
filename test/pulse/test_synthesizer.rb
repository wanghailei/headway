# Tests for Pulse::Synthesizer two-stage pipeline. Stage 1 extracts
# issues from collected items. Stage 2 synthesizes a status section for
# each issue. Includes tests for iterative reporting with previous
# report context. Uses FakeAIClient from test_helper.

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
		Pulse::Synthesizer.new( fake ).synthesize( items )

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
		result = Pulse::Synthesizer.new( fake ).synthesize( items )

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
		result = Pulse::Synthesizer.new( fake ).synthesize( items )

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
		Pulse::Synthesizer.new( fake ).synthesize( items )

		synth_prompt = fake.calls[1][:prompt]
		assert_includes synth_prompt, "Deployment"
		assert_includes synth_prompt, "Deployed v2."
		assert_includes synth_prompt, "Rollback plan ready."
	end

	def test_falls_back_on_invalid_extraction_json
		items = [
			{ name: "Reports", files: [ { filename: "update.md", content: "progress" } ] }
		]

		fake = FakeAIClient.new( "not valid json at all", "### 综合更新\n概要。" )
		result = Pulse::Synthesizer.new( fake ).synthesize( items )

		# Fallback creates one "综合更新" issue → 1 extraction + 1 synthesis
		assert_equal 2, fake.calls.length
		assert_includes fake.calls[1][:prompt], "综合更新"
		assert_equal "### 综合更新\n概要。", result
	end

	def test_strips_code_fences_from_extraction_response
		items = [
			{ name: "Reports", files: [ { filename: "update.md", content: "data" } ] }
		]

		wrapped = "```json\n[{\"name\": \"Bug Fix\", \"excerpts\": [\"data\"]}]\n```"
		fake = FakeAIClient.new( wrapped, "### Bug Fix\nFixed." )
		result = Pulse::Synthesizer.new( fake ).synthesize( items )

		assert_equal 2, fake.calls.length
		assert_includes result, "Bug Fix"
	end

	def test_returns_empty_string_for_no_items
		fake = FakeAIClient.new( "should not be called" )
		result = Pulse::Synthesizer.new( fake ).synthesize( [] )

		assert_equal "", result
		assert_equal 0, fake.calls.length
	end

	def test_extraction_uses_extract_system_prompt
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		extraction_json = JSON.generate( [ { name: "X", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Pulse::Synthesizer.new( fake ).synthesize( items )

		extract_system = fake.calls[0][:system]
		assert_includes extract_system, "识别"
		assert_includes extract_system, "JSON"
	end

	def test_synthesis_uses_synthesis_system_prompt
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		extraction_json = JSON.generate( [ { name: "X", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Pulse::Synthesizer.new( fake ).synthesize( items )

		synth_system = fake.calls[1][:system]
		assert_includes synth_system, "状态指示符"
		assert_includes synth_system, "🟢"
		assert_includes synth_system, "🔴"
		assert_includes synth_system, Date.today.to_s
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
		result = Pulse::Synthesizer.new( fake ).synthesize( items )

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

	# --- Iterative reporting tests ---

	def test_previous_report_included_in_extraction_prompt
		items = [ { name: "X", files: [ { filename: "a.md", content: "new update" } ] } ]
		previous = "### 🟢 Old Issue\n最后更新：2026-02-20\nOn track."

		extraction_json = JSON.generate( [ { name: "Old Issue", excerpts: [ "new update" ] } ] )
		fake = FakeAIClient.new( extraction_json, "### 🟢 Old Issue\nUpdated." )
		Pulse::Synthesizer.new( fake, previous_report: previous ).synthesize( items )

		extraction_prompt = fake.calls[0][:prompt]
		assert_includes extraction_prompt, "上期进度报告"
		assert_includes extraction_prompt, "Old Issue"
	end

	def test_previous_report_uses_iterative_extraction_system
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]
		previous = "### 🟢 Test\nOld status."

		extraction_json = JSON.generate( [ { name: "Test", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Pulse::Synthesizer.new( fake, previous_report: previous ).synthesize( items )

		extract_system = fake.calls[0][:system]
		assert_includes extract_system, "上期报告"
		assert_includes extract_system, "沿用"
	end

	def test_previous_report_section_passed_to_synthesis
		items = [ { name: "X", files: [ { filename: "a.md", content: "progress" } ] } ]
		previous = "### 🟡 Design Review\n最后更新：2026-02-20\n设计审查进行中。"

		extraction_json = JSON.generate( [ { name: "Design Review", excerpts: [ "progress" ] } ] )
		fake = FakeAIClient.new( extraction_json, "### 🟢 Design Review\nDone." )
		Pulse::Synthesizer.new( fake, previous_report: previous ).synthesize( items )

		synth_prompt = fake.calls[1][:prompt]
		assert_includes synth_prompt, "上期状态"
		assert_includes synth_prompt, "设计审查进行中"
	end

	def test_previous_report_uses_iterative_synthesis_system
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]
		previous = "### 🟢 Test\nOld."

		extraction_json = JSON.generate( [ { name: "Test", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Pulse::Synthesizer.new( fake, previous_report: previous ).synthesize( items )

		synth_system = fake.calls[1][:system]
		assert_includes synth_system, "上期"
		assert_includes synth_system, "变化"
	end

	def test_without_previous_report_uses_standard_prompts
		items = [ { name: "X", files: [ { filename: "a.md", content: "b" } ] } ]

		extraction_json = JSON.generate( [ { name: "X", excerpts: [ "b" ] } ] )
		fake = FakeAIClient.new( extraction_json, "ok" )
		Pulse::Synthesizer.new( fake ).synthesize( items )

		extract_system = fake.calls[0][:system]
		refute_includes extract_system, "上期报告"

		synth_prompt = fake.calls[1][:prompt]
		refute_includes synth_prompt, "上期状态"
	end
end
