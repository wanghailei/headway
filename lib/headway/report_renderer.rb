# ERB-based report renderer for Headway. Reads a markdown ERB template
# and renders it with the supplied date and body content to produce
# the final formatted report.

require "erb"

module Headway
	class ReportRenderer
		def initialize( template_path = "templates/report.md.erb" )
			@template = File.read( template_path )
		end

		def render( date:, body: )
			ERB.new( @template, trim_mode: "-" ).result( binding )
		end
	end
end
