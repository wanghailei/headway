# Configuration loader for Headway. Reads YAML config and provides
# accessor methods. Placeholder until Task 2 adds full implementation.

require "yaml"

module Headway
	class Config
		attr_reader :data

		def initialize( path = "config/headway.yml" )
			@data = YAML.load_file( path )
		end
	end
end
