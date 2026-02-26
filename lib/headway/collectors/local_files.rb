# Convention-based local file collector. Scans a directory for updates:
#
# 1. Each top-level subfolder represents a "thing" (project, issue, goal)
#    and contains date-prefixed markdown files. Folders starting with "_"
#    are ignored (templates, archives, etc.).
#
# 2. Loose .md files at the root level are collected as individual items,
#    using the filename (without extension) as the item name. This allows
#    simple drop-in usage: employees drop meeting notes or issue reports
#    directly into the folder without creating subfolders.

module Headway
	module Collectors
		class LocalFiles
			def initialize( path )
				@path = path
			end

			def collect
				return [] unless File.directory?( @path )

				items = []
				items.concat( collect_folders )
				items.concat( collect_loose_files )
				items
			end

		private

			def collect_folders
				Dir.children( @path )
					.select do | name |
						File.directory?( File.join( @path, name ) )
					end
					.reject do | name |
						name.start_with?( "_" ) || name.start_with?( "." )
					end
					.sort
					.map do | name |
						collect_thing( name )
					end
			end

			def collect_loose_files
				Dir.children( @path )
					.select do | name |
						name.end_with?( ".md" ) && !name.start_with?( "." )
					end
					.sort
					.map do | name |
						item_name = File.basename( name, ".md" ).force_encoding( "UTF-8" )
						{
							name: item_name,
							files: [ read_file( @path, name ) ]
						}
					end
			end

			def collect_thing( name )
				thing_path = File.join( @path, name )
				files = Dir.children( thing_path )
					.select do | f |
						f.end_with?( ".md" )
					end
					.sort
					.map do | f |
						read_file( thing_path, f )
					end

				{ name: name, files: files }
			end

			def read_file( dir, filename )
				path = File.join( dir, filename )
				{ filename: filename, content: File.read( path, encoding: "UTF-8" ) }
			end
		end
	end
end
