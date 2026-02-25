# Markdown file publisher for Headway. Writes rendered report content
# to a local file, auto-creating parent directories if they don't
# already exist.

require "fileutils"

module Headway
	module Publishers
		class MarkdownFile
			def initialize( path )
				@path = path
			end

			def publish( content )
				FileUtils.mkdir_p( File.dirname( @path ) )
				File.write( @path, content )
			end
		end
	end
end
