# Anthropic Messages API client. Sends prompts to Claude models via
# the /v1/messages endpoint using Faraday. Shares the same chat
# interface as AIClient so Runner can use either interchangeably.

require "faraday"

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
		def chat( prompt, system: nil, connection: nil )
			conn = connection || build_connection

			body = {
				model: @model,
				max_tokens: 4096,
				messages: [ { role: "user", content: prompt } ]
			}
			body[:system] = system if system

			response = conn.post( "/v1/messages", body )

			unless response.success?
				error_msg = response.body.is_a?( Hash ) ? response.body.dig( "error", "message" ) : nil
				raise APIError, "Anthropic API returned #{response.status}: #{error_msg || response.body.to_s}"
			end

			# Anthropic returns content as an array of blocks.
			response.body.dig( "content", 0, "text" )
		end

	private

		def build_connection
			Faraday.new( url: @base_url ) do | f |
				f.request :json
				f.response :json
				f.headers["x-api-key"] = @api_key
				f.headers["anthropic-version"] = ANTHROPIC_VERSION
				f.adapter Faraday.default_adapter
			end
		end
	end
end
