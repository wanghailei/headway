# Markdown file publisher for Headway. Writes rendered report content
# to a timestamped local file (RP.YY.MM.DD.HH.md), auto-creating
# parent directories if they don't already exist.

require "fileutils"

module Headway
	module Publishers
		class MarkdownFile
			def initialize( path )
				@dir = path.end_with?( ".md" ) ? File.dirname( path ) : path
			end

			def publish( content )
				FileUtils.mkdir_p( @dir )
				filename = "RP.#{Time.now.strftime( "%y.%m.%d.%H" )}.md"
				filepath = File.join( @dir, filename )
				File.write( filepath, content )
				filepath
			end
		end
	end
end
