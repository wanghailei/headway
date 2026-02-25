# OpenAI-compatible chat client. Sends prompts to LLM providers via
# the standard chat completions endpoint using net/http. Works with
# OpenAI, Qwen, DeepSeek, and any compatible API.

require "net/http"
require "uri"
require "json"

module Headway
	class AIClient
		def initialize( base_url:, api_key:, model: )
			@base_url = base_url
			@api_key = api_key
			@model = model
		end

		def chat( prompt, system: nil )
			uri = URI( "#{@base_url}/chat/completions" )

			messages = []
			messages << { role: "system", content: system } if system
			messages << { role: "user", content: prompt }

			body = { model: @model, messages: messages }

			response = post( uri, body )
			data = JSON.parse( response.body )
			data.dig( "choices", 0, "message", "content" )
		end

	private

		def post( uri, body )
			http = Net::HTTP.new( uri.host, uri.port )
			http.use_ssl = ( uri.scheme == "https" )

			request = Net::HTTP::Post.new( uri.path )
			request["Content-Type"] = "application/json"
			request["Authorization"] = "Bearer #{@api_key}"
			request.body = JSON.generate( body )

			http.request( request )
		end
	end
end
