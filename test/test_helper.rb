# Shared test configuration for Headway. Sets up Bundler, loads Headway
# (which activates Zeitwerk autoloading), and configures minitest.

require "bundler/setup"
require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path( "../lib", __dir__ )
require "headway"

# Fake AI client for testing. Accepts one or more responses and returns
# them sequentially across chat calls. If more calls are made than
# responses provided, the last response is reused.
class FakeAIClient
	attr_reader :calls

	def initialize( *responses )
		@responses = responses.flatten
		@calls = []
		@index = 0
	end

	def chat( prompt, system: nil )
		@calls << { prompt: prompt, system: system }
		response = @index < @responses.length ? @responses[@index] : @responses.last
		@index += 1
		response
	end

	def last_prompt
		@calls.last&.dig( :prompt )
	end

	def last_system
		@calls.last&.dig( :system )
	end
end
