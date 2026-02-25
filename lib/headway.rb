# Main entry point for the Headway module. Sets up Zeitwerk autoloading
# so all classes under lib/headway/ are loaded on demand — no manual
# require_relative chains needed.

require "zeitwerk"

module Headway
	VERSION = "0.1.0"
end

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
	"ai_client" => "AIClient",
	"cli" => "CLI"
)
loader.setup
