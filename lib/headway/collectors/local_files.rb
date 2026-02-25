# Convention-based local file collector. Scans a directory where each
# top-level subfolder represents a "thing" (project, issue, goal) and
# contains date-prefixed markdown files. Folders starting with "_"
# are ignored (templates, archives, etc.).

module Headway
	module Collectors
		class LocalFiles
			def initialize( path )
				@path = path
			end

			def collect
				Dir.children( @path )
					.select do | name |
						File.directory?( File.join( @path, name ) )
					end
					.reject do | name |
						name.start_with?( "_" )
					end
					.sort
					.map do | name |
						collect_thing( name )
					end
			end

		private

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
				{ filename: filename, content: File.read( path ) }
			end
		end
	end
end
