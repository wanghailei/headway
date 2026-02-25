# Tests for Headway::Publishers::MarkdownFile. Verifies that the
# publisher writes markdown content to a file and auto-creates
# parent directories when they don't exist.

require "test_helper"
require "headway/publishers/markdown_file"

class TestMarkdownFilePublisher < Minitest::Test
	def setup
		@dir = Dir.mktmpdir
		@output_path = File.join( @dir, "output", "report.md" )
	end

	def teardown
		FileUtils.rm_rf( @dir )
	end

	def test_writes_report_to_file
		publisher = Headway::Publishers::MarkdownFile.new( @output_path )
		publisher.publish( "# Report\n\nContent here." )

		assert File.exist?( @output_path )
		assert_equal "# Report\n\nContent here.", File.read( @output_path )
	end

	def test_creates_parent_directories
		publisher = Headway::Publishers::MarkdownFile.new( @output_path )
		publisher.publish( "test" )

		assert File.directory?( File.dirname( @output_path ) )
	end
end
