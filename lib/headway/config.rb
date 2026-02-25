# Configuration loader for Headway. Reads a YAML config file and exposes
# typed accessors for AI settings, collectors, and publishers.
# Environment variables override file-based values where supported.

require "yaml"

module Headway
	class Config
		def initialize( path = "config/headway.yml" )
			@data = YAML.load_file( path )
		end

		# Provider type: "openai" (default) or "anthropic".
		def ai_provider
			ENV["HEADWAY_AI_PROVIDER"] || @data.dig( "ai", "provider" ) || "openai"
		end

		def ai_base_url
			ENV["HEADWAY_AI_BASE_URL"] || @data.dig( "ai", "base_url" )
		end

		def ai_model
			ENV["HEADWAY_AI_MODEL"] || @data.dig( "ai", "model" )
		end

		# API key is environment-only for security — never loaded from config file.
		# Falls back to OPENAI_API_KEY for compatibility with Codex CLI and
		# other OpenAI tools that use the standard variable name.
		def ai_api_key
			ENV["HEADWAY_AI_API_KEY"] || ENV["OPENAI_API_KEY"]
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
	end
end
