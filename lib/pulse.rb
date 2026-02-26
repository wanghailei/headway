# Sets up Zeitwerk autoloading so all classes under lib/pulse/ are
# loaded on demand — no manual require_relative chains needed.

require "zeitwerk"

module Pulse
	VERSION = "0.2.0"
end

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
	"ai_client" => "AIClient",
	"cli" => "CLI",
	"dingtalk" => "DingTalk"
)
loader.setup
