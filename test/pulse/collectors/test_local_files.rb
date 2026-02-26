# Tests for Pulse::Collectors::LocalFiles. Verifies convention-based
# folder scanning: thing discovery, file sorting, content reading,
# underscore-prefixed folder exclusion, and loose file collection.

require "test_helper"
require "pulse/collectors/local_files"

class TestLocalFilesCollector < Minitest::Test
	def setup
		@dir = Dir.mktmpdir

		# Create two "things" with files
		FileUtils.mkdir_p( File.join( @dir, "Project Alpha" ) )
		File.write(
			File.join( @dir, "Project Alpha", "2026-02-18-kickoff.md" ),
			"# Kickoff\nProject started. Team assigned."
		)
		File.write(
			File.join( @dir, "Project Alpha", "2026-02-25-weekly.md" ),
			"# Weekly\nSprint 4 on track. Backend done."
		)

		FileUtils.mkdir_p( File.join( @dir, "Login Timeout" ) )
		File.write(
			File.join( @dir, "Login Timeout", "2026-02-24-resolved.md" ),
			"# Resolved\nFixed connection pool. Deployed Monday."
		)

		# Ignored folders
		FileUtils.mkdir_p( File.join( @dir, "_templates" ) )
		File.write(
			File.join( @dir, "_templates", "weekly-update.md" ),
			"template content"
		)
	end

	def teardown
		FileUtils.rm_rf( @dir )
	end

	def test_collects_all_things
		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		names = items.map do | i |
			i[:name]
		end.sort
		assert_equal [ "Login Timeout", "Project Alpha" ], names
	end

	def test_collects_files_sorted_by_date
		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		alpha = items.find do | i |
			i[:name] == "Project Alpha"
		end
		assert_equal 2, alpha[:files].length
		assert_match( /kickoff/, alpha[:files].first[:filename] )
		assert_match( /weekly/, alpha[:files].last[:filename] )
	end

	def test_reads_file_content
		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		alpha = items.find do | i |
			i[:name] == "Project Alpha"
		end
		assert_includes alpha[:files].last[:content], "Sprint 4 on track"
	end

	def test_ignores_underscore_folders
		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		names = items.map do | i |
			i[:name]
		end
		refute_includes names, "_templates"
	end

	def test_collects_loose_md_files
		File.write( File.join( @dir, "周例会笔记.md" ), "# 周例会\n讨论了项目进度。" )

		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect

		meeting_item = items.find { | i | i[:name] == "周例会笔记" }
		assert meeting_item, "Should collect loose .md files"
		assert_equal 1, meeting_item[:files].length
		assert_includes meeting_item[:files][0][:content], "讨论了项目进度"
	end

	def test_loose_files_use_filename_as_name
		File.write( File.join( @dir, "Q1-Review.md" ), "# Q1 Review\nMet targets." )

		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect

		review = items.find { | i | i[:name] == "Q1-Review" }
		assert review, "Should use filename without extension as name"
	end

	def test_returns_empty_for_nonexistent_path
		collector = Pulse::Collectors::LocalFiles.new( "/tmp/nonexistent_#{$$}" )
		items = collector.collect

		assert_equal [], items
	end

	def test_ignores_dotfiles
		File.write( File.join( @dir, ".gitkeep" ), "" )

		collector = Pulse::Collectors::LocalFiles.new( @dir )
		items = collector.collect

		names = items.map { | i | i[:name] }
		refute names.any? { | n | n.start_with?( "." ) }
	end
end
