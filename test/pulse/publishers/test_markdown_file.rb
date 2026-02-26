# Tests for Pulse::Publishers::MarkdownFile. Verifies timestamped
# report output (RP.YY.MM.DD.HH.md) and auto-creation of parent
# directories when they don't exist.

require "test_helper"

class TestMarkdownFilePublisher < Minitest::Test
	def setup
		@dir = Dir.mktmpdir
		@output_dir = File.join( @dir, "output" )
	end

	def teardown
		FileUtils.rm_rf( @dir )
	end

	def test_writes_report_with_timestamped_filename
		publisher = Pulse::Publishers::MarkdownFile.new( @output_dir )
		filepath = publisher.publish( "# Report\n\nContent here." )

		assert File.exist?( filepath )
		assert_match( /RP\.\d{2}\.\d{2}\.\d{2}\.\d{2}\.md\z/, filepath )
		assert_equal "# Report\n\nContent here.", File.read( filepath )
	end

	def test_creates_parent_directories
		publisher = Pulse::Publishers::MarkdownFile.new( @output_dir )
		publisher.publish( "test" )

		assert File.directory?( @output_dir )
	end

	def test_accepts_directory_path
		publisher = Pulse::Publishers::MarkdownFile.new( @output_dir )
		filepath = publisher.publish( "content" )

		assert_equal @output_dir, File.dirname( filepath )
	end
end
