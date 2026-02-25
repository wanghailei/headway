# Pipeline orchestrator for Headway. Ties together the full workflow:
# collect items from configured sources, synthesize via AI, render
# the report template, and publish to configured destinations.

require_relative "config"
require_relative "ai_client"
require_relative "anthropic_client"
require_relative "collectors/local_files"
require_relative "synthesizer"
require_relative "report_renderer"
require_relative "publishers/markdown_file"

module Headway
	class Runner
		def initialize( config, ai_client: nil, template_path: "templates/report.md.erb" )
			@config = config
			@ai_client = ai_client || build_ai_client
			@template_path = template_path
		end

		def run
			items = collect
			body = synthesize( items )
			report = render( body )
			publish( report )
		end

	private

		def collect
			items = []
			@config.collectors.each do | c |
				case c["type"]
				when "local_files"
					items.concat Collectors::LocalFiles.new( c["path"] ).collect
				end
			end
			items
		end

		def synthesize( items )
			Synthesizer.new( @ai_client ).synthesize( items )
		end

		def render( body )
			ReportRenderer.new( @template_path ).render(
				date: Time.now.strftime( "%Y-%m-%d" ),
				body: body
			)
		end

		def publish( report )
			@config.publishers.each do | p |
				case p["type"]
				when "markdown_file"
					Publishers::MarkdownFile.new( p["path"] ).publish( report )
				end
			end
		end

		def build_ai_client
			case @config.ai_provider
			when "anthropic"
				AnthropicClient.new(
					base_url: @config.ai_base_url,
					api_key: @config.ai_api_key,
					model: @config.ai_model
				)
			else
				AIClient.new(
					base_url: @config.ai_base_url,
					api_key: @config.ai_api_key,
					model: @config.ai_model
				)
			end
		end
	end
end
