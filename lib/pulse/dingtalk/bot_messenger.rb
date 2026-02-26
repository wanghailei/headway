# Sends messages to individual DingTalk users via the robot batch send
# API. Used to push report notifications to whitelisted users after
# each pipeline run.

require "json"

module Pulse
	module DingTalk
		class BotMessenger
			BATCH_SEND_PATH = "/v1.0/robot/oToMessages/batchSend"
			MAX_BATCH_SIZE = 20
			MAX_CONTENT_LENGTH = 20_000

			def initialize( client:, robot_code: )
				@client = client
				@robot_code = robot_code
			end

			# Send a markdown message to a list of user IDs.
			def send_markdown( user_ids:, title:, content: )
				return if user_ids.nil? || user_ids.empty?

				text = truncate( content )

				user_ids.each_slice( MAX_BATCH_SIZE ) do | batch |
					@client.post(
						BATCH_SEND_PATH,
						body: {
							robotCode: @robot_code,
							userIds: batch,
							msgKey: "sampleMarkdown",
							msgParam: JSON.generate( {
								title: title,
								text: text
							} )
						}
					)
				end
			end

		private

			def truncate( text )
				return text if text.length <= MAX_CONTENT_LENGTH
				text[0...MAX_CONTENT_LENGTH] + "\n\n...(truncated)"
			end
		end
	end
end
