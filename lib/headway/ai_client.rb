# OpenAI-compatible chat client. Sends prompts to LLM providers via
# the standard chat completions endpoint using Faraday. Works with
# OpenAI, Qwen, DeepSeek, and any compatible API. Raises on HTTP
# errors so failures are visible rather than silently swallowed.

require "faraday"

module Headway
	class AIClient
		# Raised when the API returns a non-2xx response.
		class APIError < StandardError; end

		def initialize( base_url:, api_key:, model: )
			raise ArgumentError, "api_key is required (set HEADWAY_AI_API_KEY)" unless api_key
			@base_url = base_url
			@api_key = api_key
			@model = model
		end

		def chat( prompt, system: nil, connection: nil )
			conn = connection || build_connection

			messages = []
			messages << { role: "system", content: system } if system
			messages << { role: "user", content: prompt }

			body = { model: @model, messages: messages }

			response = conn.post( "chat/completions", body )

			unless response.success?
				error_msg = response.body.is_a?( Hash ) ? response.body.dig( "error", "message" ) : nil
				raise APIError, "AI API returned #{response.status}: #{error_msg || response.body.to_s}"
			end

			response.body.dig( "choices", 0, "message", "content" )
		end

	private

		def build_connection
			# Trailing slash ensures relative POST paths append correctly.
			base = @base_url.end_with?( "/" ) ? @base_url : "#{@base_url}/"
			Faraday.new( url: base ) do | f |
				f.request :json
				f.response :json
				f.headers["Authorization"] = "Bearer #{@api_key}"
				f.adapter Faraday.default_adapter
			end
		end
	end
end
