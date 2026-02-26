# ERB-based report renderer. Reads a markdown ERB template and renders
# it with the supplied date and body content to produce the final
# formatted report.

require "erb"

module Pulse
	class ReportRenderer
		def initialize( template_path = "templates/report.md.erb" )
			@template = File.read( template_path, encoding: "UTF-8" )
		end

		def render( date:, body: )
			ERB.new( @template, trim_mode: "-" ).result( binding )
		end
	end
end
