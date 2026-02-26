# DingTalk Doc publisher. Updates a single living DingTalk document
# in-place with the rendered report. The document must already exist —
# the publisher overwrites its content each cycle.

module Pulse
	module Publishers
		class DingtalkDoc
			def initialize( client:, space_id:, doc_id:, operator_user_id: )
				@client = client
				@space_id = space_id
				@doc_id = doc_id
				@operator_user_id = operator_user_id
			end

			def publish( content )
				@client.post(
					"/v1.0/doc/spaces/#{@space_id}/docs/#{@doc_id}/contents/update",
					body: {
						operatorId: @operator_user_id,
						content: content,
						sourceFormat: "markdown"
					}
				)
			end
		end
	end
end
