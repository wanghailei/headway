# DingTalk bot @mention collector. Drains a Thread::Queue of messages
# received by the Stream listener. Each mention becomes a file in a
# single "Bot Mentions" section.

module Pulse
	module Collectors
		class DingtalkMentions
			def initialize( queue:, doc_reader: nil )
				@queue = queue
				@doc_reader = doc_reader
			end

			def collect
				messages = drain_queue
				return [] if messages.empty?

				files = messages.map { | msg | format_mention( msg ) }
				[ { name: "Bot Mentions", files: files } ]
			end

		private

			def drain_queue
				messages = []
				messages << @queue.pop( true ) until @queue.empty?
				messages
			rescue ThreadError
				# Queue was empty
				messages
			end

			def format_mention( msg )
				sender = msg["senderNick"] || "unknown"
				text = extract_text( msg )
				time = format_time( msg["createAt"] )

				content = "# @mention from #{sender}\n\n"
				content += "- **发送人**: #{sender}\n"
				content += "- **时间**: #{time}\n\n" if time
				content += text
				content += fetch_doc_contents( text, msg["senderStaffId"] )

				{ filename: "mention-#{sender}-#{time || "unknown"}", content: content }
			end

			def fetch_doc_contents( text, sender_staff_id )
				return "" unless @doc_reader && sender_staff_id

				urls = DingTalk::DocReader.extract_urls( text )
				return "" if urls.empty?

				parts = urls.filter_map do | url |
					body = @doc_reader.fetch( url, operator_id: sender_staff_id )
					"\n\n---\n\n**附件文档** (#{url}):\n\n#{body}" if body
				end
				parts.join
			end

			def extract_text( msg )
				msg.dig( "text", "content" )&.strip || msg["content"] || ""
			end

			def format_time( ms )
				return nil unless ms
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d %H:%M" )
			rescue
				nil
			end
		end
	end
end
