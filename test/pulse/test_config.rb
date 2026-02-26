# Tests for Pulse::Config. Verifies YAML loading, typed accessors,
# and environment variable override behaviour.

require "test_helper"

class TestConfig < Minitest::Test
	def setup
		@dir = Dir.mktmpdir
		@config_path = File.join( @dir, "pulse.yml" )
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
		config = Pulse::Config.new( @config_path )
		assert_equal "https://api.openai.com/v1", config.ai_base_url
		assert_equal "gpt-4o", config.ai_model
	end

	def test_ai_api_key_from_pulse_env
		ENV["PULSE_AI_API_KEY"] = "pulse-key"
		ENV["OPENAI_API_KEY"] = "openai-key"
		config = Pulse::Config.new( @config_path )
		assert_equal "pulse-key", config.ai_api_key
	ensure
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV.delete( "OPENAI_API_KEY" )
	end

	def test_ai_api_key_falls_back_to_openai_env
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV["OPENAI_API_KEY"] = "openai-key"
		config = Pulse::Config.new( @config_path )
		assert_equal "openai-key", config.ai_api_key
	ensure
		ENV.delete( "OPENAI_API_KEY" )
	end

	def test_ai_api_key_falls_back_to_codex_auth
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV.delete( "OPENAI_API_KEY" )

		# Write a fake Codex auth file
		codex_dir = File.join( @dir, ".codex" )
		FileUtils.mkdir_p( codex_dir )
		auth_path = File.join( codex_dir, "auth.json" )
		File.write( auth_path, JSON.generate( {
			"tokens" => { "access_token" => "codex-oauth-token" }
		} ) )

		# Point Config at our fake auth path
		original = Pulse::Config::CODEX_AUTH_PATH
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, auth_path )

		config = Pulse::Config.new( @config_path )
		assert_equal "codex-oauth-token", config.ai_api_key
	ensure
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, original )
	end

	def test_ai_api_key_nil_when_no_source_available
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV.delete( "OPENAI_API_KEY" )

		# Point Config at a nonexistent file
		original = Pulse::Config::CODEX_AUTH_PATH
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, File.join( @dir, "nope.json" ) )

		config = Pulse::Config.new( @config_path )
		assert_nil config.ai_api_key
	ensure
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, original )
	end

	def test_ai_api_key_survives_corrupt_codex_auth
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV.delete( "OPENAI_API_KEY" )

		# Write corrupt JSON
		codex_dir = File.join( @dir, ".codex" )
		FileUtils.mkdir_p( codex_dir )
		auth_path = File.join( codex_dir, "auth.json" )
		File.write( auth_path, "NOT-JSON{{{" )

		original = Pulse::Config::CODEX_AUTH_PATH
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, auth_path )

		config = Pulse::Config.new( @config_path )
		assert_nil config.ai_api_key
	ensure
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, original )
	end

	def test_using_codex_auth_true_when_only_codex_token
		ENV.delete( "PULSE_AI_API_KEY" )
		ENV.delete( "OPENAI_API_KEY" )

		codex_dir = File.join( @dir, ".codex" )
		FileUtils.mkdir_p( codex_dir )
		auth_path = File.join( codex_dir, "auth.json" )
		File.write( auth_path, JSON.generate( {
			"tokens" => { "access_token" => "codex-oauth-token" }
		} ) )

		original = Pulse::Config::CODEX_AUTH_PATH
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, auth_path )

		config = Pulse::Config.new( @config_path )
		assert config.using_codex_auth?
	ensure
		Pulse::Config.send( :remove_const, :CODEX_AUTH_PATH )
		Pulse::Config.const_set( :CODEX_AUTH_PATH, original )
	end

	def test_using_codex_auth_false_when_env_key_set
		ENV["PULSE_AI_API_KEY"] = "explicit-key"
		config = Pulse::Config.new( @config_path )
		refute config.using_codex_auth?
	ensure
		ENV.delete( "PULSE_AI_API_KEY" )
	end

	def test_env_overrides_base_url
		ENV["PULSE_AI_BASE_URL"] = "https://custom.api.com/v1"
		config = Pulse::Config.new( @config_path )
		assert_equal "https://custom.api.com/v1", config.ai_base_url
	ensure
		ENV.delete( "PULSE_AI_BASE_URL" )
	end

	def test_collectors_config
		config = Pulse::Config.new( @config_path )
		assert_equal 1, config.collectors.length
		assert_equal "local_files", config.collectors.first["type"]
	end

	def test_publishers_config
		config = Pulse::Config.new( @config_path )
		assert_equal 1, config.publishers.length
		assert_equal "markdown_file", config.publishers.first["type"]
	end

	def test_dingtalk_app_key_from_env
		ENV["DINGTALK_APP_KEY"] = "dk-test-key"
		config = Pulse::Config.new( @config_path )
		assert_equal "dk-test-key", config.dingtalk_app_key
	ensure
		ENV.delete( "DINGTALK_APP_KEY" )
	end

	def test_dingtalk_app_secret_from_env
		ENV["DINGTALK_APP_SECRET"] = "dk-test-secret"
		config = Pulse::Config.new( @config_path )
		assert_equal "dk-test-secret", config.dingtalk_app_secret
	ensure
		ENV.delete( "DINGTALK_APP_SECRET" )
	end

	def test_dingtalk_credentials_nil_when_unset
		ENV.delete( "DINGTALK_APP_KEY" )
		ENV.delete( "DINGTALK_APP_SECRET" )
		config = Pulse::Config.new( @config_path )
		assert_nil config.dingtalk_app_key
		assert_nil config.dingtalk_app_secret
	end
end
