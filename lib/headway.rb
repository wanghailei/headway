# Main entry point for the Headway module. Defines the version constant
# and loads core dependencies.

require_relative "headway/config"
require_relative "headway/runner"

module Headway
	VERSION = "0.1.0"
end
