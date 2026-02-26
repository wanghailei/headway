# Configuration loader. Reads a YAML config file and exposes typed
# accessors for AI settings, collectors, and publishers. Environment
# variables override file-based values where supported. When no
# explicit API key is set, reads the Codex CLI OAuth token from
# ~/.codex/auth.json as a last-resort fallback.

require "yaml"
require "json"

module Pulse
	class Config
		CODEX_AUTH_PATH = File.expand_path( "~/.codex/auth.json" )

		def initialize( path = "config/pulse.yml" )
			@data = YAML.load_file( path )
		end

		def ai_base_url
			ENV["PULSE_AI_BASE_URL"] || @data.dig( "ai", "base_url" )
		end

		def ai_model
			ENV["PULSE_AI_MODEL"] || @data.dig( "ai", "model" )
		end

		# API key resolution order:
		#   1. PULSE_AI_API_KEY  — explicit app-specific key
		#   2. OPENAI_API_KEY    — standard OpenAI / Codex env var
		#   3. ~/.codex/auth.json — OAuth access token from Codex CLI login
		def ai_api_key
			ENV["PULSE_AI_API_KEY"] || ENV["OPENAI_API_KEY"] || codex_access_token
		end

		def collectors
			@data.fetch( "collectors", [] )
		end

		def publishers
			@data.fetch( "publishers", [] )
		end

		def interval_hours
			@data.dig( "schedule", "interval_hours" ) || 2
		end

		def dingtalk_app_key
			ENV["DINGTALK_APP_KEY"]
		end

		def dingtalk_app_secret
			ENV["DINGTALK_APP_SECRET"]
		end

		# True when the API key came from Codex CLI's OAuth token rather
		# than an explicit env var. Runner uses this to pick the Responses
		# API endpoint (covered by ChatGPT Pro) instead of Chat Completions.
		def using_codex_auth?
			ENV["PULSE_AI_API_KEY"].nil? && ENV["OPENAI_API_KEY"].nil? && !codex_access_token.nil?
		end

	private

		# Reads the OAuth access token that Codex CLI stores after
		# `codex` login. Returns nil when the file is missing or
		# the token field is absent — callers treat nil as "no key".
		def codex_access_token
			return nil unless File.exist?( CODEX_AUTH_PATH )
			auth = JSON.parse( File.read( CODEX_AUTH_PATH ) )
			token = auth.dig( "tokens", "access_token" )
			token && !token.empty? ? token : nil
		rescue JSON::ParserError
			nil
		end
	end
end
