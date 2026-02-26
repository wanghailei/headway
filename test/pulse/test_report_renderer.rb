# Tests for Pulse::ReportRenderer. Verifies that the ERB template
# renders a markdown report with the supplied date and body content.

require "test_helper"

class TestReportRenderer < Minitest::Test
	def setup
		@template_dir = Dir.mktmpdir
		@template_path = File.join( @template_dir, "report.md.erb" )
		File.write( @template_path, <<~ERB )
			# Pulse Report — <%= date %>

			<%= body %>
		ERB
	end

	def teardown
		FileUtils.rm_rf( @template_dir )
	end

	def test_renders_report_with_date_and_body
		renderer = Pulse::ReportRenderer.new( @template_path )
		result = renderer.render(
			date: "2026-02-25",
			body: "### 🟢 Project Alpha\nOn track."
		)

		assert_includes result, "# Pulse Report — 2026-02-25"
		assert_includes result, "### 🟢 Project Alpha"
		assert_includes result, "On track."
	end
end
