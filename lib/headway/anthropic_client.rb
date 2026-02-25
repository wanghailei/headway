# Anthropic Messages API client. Sends prompts to Claude models via
# the /v1/messages endpoint using net/http. Shares the same chat
# interface as AIClient so Runner can use either interchangeably.

require "net/http"
require "uri"
require "json"

module Headway
	class AnthropicClient
		# Raised when the API returns a non-2xx response.
		class APIError < StandardError; end

		ANTHROPIC_VERSION = "2023-06-01"

		def initialize( base_url:, api_key:, model: )
			raise ArgumentError, "api_key is required (set HEADWAY_AI_API_KEY)" unless api_key
			@base_url = base_url
			@api_key = api_key
			@model = model
		end

		# Same interface as AIClient#chat — accepts a prompt and optional
		# system message, returns the response text.
		def chat( prompt, system: nil )
			uri = URI( "#{@base_url}/v1/messages" )

			body = {
				model: @model,
				max_tokens: 4096,
				messages: [ { role: "user", content: prompt } ]
			}
			body[:system] = system if system

			response = post( uri, body )
			data = JSON.parse( response.body )

			unless response.is_a?( Net::HTTPSuccess )
				error_msg = data.dig( "error", "message" ) || response.body
				raise APIError, "Anthropic API returned #{response.code}: #{error_msg}"
			end

			# Anthropic returns content as an array of blocks.
			data.dig( "content", 0, "text" )
		end

	private

		def post( uri, body )
			http = Net::HTTP.new( uri.host, uri.port )
			http.use_ssl = ( uri.scheme == "https" )

			request = Net::HTTP::Post.new( uri.path )
			request["Content-Type"] = "application/json"
			request["x-api-key"] = @api_key
			request["anthropic-version"] = ANTHROPIC_VERSION
			request.body = JSON.generate( body )

			http.request( request )
		end
	end
end
