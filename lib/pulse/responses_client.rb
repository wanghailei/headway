# OpenAI Responses API client. Uses the /v1/responses endpoint which
# is covered by ChatGPT Pro/Plus subscriptions (unlike Chat Completions).
# Shares the same chat interface as AIClient so Runner can swap freely.

require "faraday"

module Pulse
	class ResponsesClient
		# Raised when the API returns a non-2xx response.
		class APIError < StandardError; end

		def initialize( base_url:, api_key:, model: )
			raise ArgumentError, "api_key is required (set PULSE_AI_API_KEY)" unless api_key
			@base_url = base_url
			@api_key = api_key
			@model = model
		end

		# Same interface as AIClient#chat — accepts a prompt and optional
		# system message, returns the response text.
		def chat( prompt, system: nil, connection: nil )
			conn = connection || build_connection

			body = { model: @model, input: prompt }
			body[:instructions] = system if system

			response = conn.post( "responses", body )

			unless response.success?
				error_msg = response.body.is_a?( Hash ) ? response.body.dig( "error", "message" ) : nil
				raise APIError, "Responses API returned #{response.status}: #{error_msg || response.body.to_s}"
			end

			extract_text( response.body )
		end

	private

		def build_connection
			base = @base_url.end_with?( "/" ) ? @base_url : "#{@base_url}/"
			Faraday.new( url: base ) do | f |
				f.request :json
				f.response :json
				f.headers["Authorization"] = "Bearer #{@api_key}"
				f.adapter Faraday.default_adapter
			end
		end

		# Finds the first "message" item in the output array and returns
		# its text. The output can contain reasoning, tool calls, etc. —
		# we only care about the assistant's message.
		def extract_text( body )
			output = body.fetch( "output", [] )
			message = output.find { | item | item["type"] == "message" }
			return nil unless message

			content = message.fetch( "content", [] )
			text_part = content.find { | part | part["type"] == "output_text" }
			text_part&.dig( "text" )
		end
	end
end
