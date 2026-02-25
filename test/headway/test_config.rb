# Tests for Headway::Config. Verifies YAML loading, typed accessors,
# and environment variable override behaviour.

require "test_helper"
require "headway/config"

class TestConfig < Minitest::Test
	def setup
		@dir = Dir.mktmpdir
		@config_path = File.join( @dir, "headway.yml" )
		File.write( @config_path, <<~YAML )
			ai:
			  base_url: https://api.openai.com/v1
			  model: gpt-4o
			collectors:
			  - type: local_files
			    path: ./input
			publishers:
			  - type: markdown_file
			    path: ./output/report.md
		YAML
	end

	def teardown
		FileUtils.rm_rf( @dir )
	end

	def test_loads_ai_config
		config = Headway::Config.new( @config_path )
		assert_equal "https://api.openai.com/v1", config.ai_base_url
		assert_equal "gpt-4o", config.ai_model
	end

	def test_ai_api_key_from_env
		ENV["HEADWAY_AI_API_KEY"] = "test-key-123"
		config = Headway::Config.new( @config_path )
		assert_equal "test-key-123", config.ai_api_key
	ensure
		ENV.delete( "HEADWAY_AI_API_KEY" )
	end

	def test_env_overrides_base_url
		ENV["HEADWAY_AI_BASE_URL"] = "https://custom.api.com/v1"
		config = Headway::Config.new( @config_path )
		assert_equal "https://custom.api.com/v1", config.ai_base_url
	ensure
		ENV.delete( "HEADWAY_AI_BASE_URL" )
	end

	def test_collectors_config
		config = Headway::Config.new( @config_path )
		assert_equal 1, config.collectors.length
		assert_equal "local_files", config.collectors.first["type"]
	end

	def test_publishers_config
		config = Headway::Config.new( @config_path )
		assert_equal 1, config.publishers.length
		assert_equal "markdown_file", config.publishers.first["type"]
	end
end
