# Detects inline priority tags in content. Tags like %P0%, {star},
# or #重要# mark items for highlighting in bot notifications.
# Shared by the synthesizer and bot notification publisher.

module Pulse
	module TagDetector
		PATTERNS = [
			/%P0%/i,
			/%P1%/i,
			/\{star\}/i,
			/#重要#/,
			/#urgent#/i
		].freeze

		# Returns true if the text contains any priority tag.
		def self.starred?( text )
			return false if text.nil?
			PATTERNS.any? { | p | p.match?( text ) }
		end

		# Returns the text with all priority tags stripped out.
		def self.strip( text )
			return "" if text.nil?
			result = text.dup
			PATTERNS.each { | p | result.gsub!( p, "" ) }
			result.strip
		end
	end
end
