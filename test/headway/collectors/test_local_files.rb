# Tests for Headway::Collectors::LocalFiles. Verifies convention-based
# folder scanning: thing discovery, file sorting, content reading,
# and underscore-prefixed folder exclusion.

require "test_helper"
require "headway/collectors/local_files"

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
		collector = Headway::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		names = items.map do | i |
			i[:name]
		end.sort
		assert_equal [ "Login Timeout", "Project Alpha" ], names
	end

	def test_collects_files_sorted_by_date
		collector = Headway::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		alpha = items.find do | i |
			i[:name] == "Project Alpha"
		end
		assert_equal 2, alpha[:files].length
		assert_match( /kickoff/, alpha[:files].first[:filename] )
		assert_match( /weekly/, alpha[:files].last[:filename] )
	end

	def test_reads_file_content
		collector = Headway::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		alpha = items.find do | i |
			i[:name] == "Project Alpha"
		end
		assert_includes alpha[:files].last[:content], "Sprint 4 on track"
	end

	def test_ignores_underscore_folders
		collector = Headway::Collectors::LocalFiles.new( @dir )
		items = collector.collect
		names = items.map do | i |
			i[:name]
		end
		refute_includes names, "_templates"
	end
end
