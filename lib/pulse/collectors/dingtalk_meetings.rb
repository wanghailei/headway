# DingTalk 闪钉会 (Flash Meeting) collector. Reads meeting history
# and cloud recording transcriptions via the DingTalk conference API.
# For each meeting within the configured time window, fetches the
# cloud recording transcript and formats it as structured markdown.
# Requires VideoConference.Conference.Read permission.

module Pulse
	module Collectors
		class DingtalkMeetings
			def initialize( client:, interval_hours: 168 )
				@client = client
				@interval_hours = interval_hours
			end

			def collect
				conferences = fetch_conferences
				return [] if conferences.empty?

				files = conferences.map do | conf |
					transcript = fetch_transcript( conf["conferenceId"] )
					format_meeting( conf, transcript )
				end

				[ { name: "Meetings", files: files } ]
			end

		private

			def fetch_conferences
				now_ms = ( Time.now.to_f * 1000 ).to_i
				start_ms = now_ms - ( @interval_hours * 3600 * 1000 )

				all_conferences = []
				next_token = nil

				loop do
					params = { startTime: start_ms.to_s, endTime: now_ms.to_s, maxResults: "20" }
					params[:nextToken] = next_token if next_token

					result = @client.get(
						"/v1.0/conference/videoConferences/histories",
						params: params
					)

					conferences = result["conferenceList"] || []
					all_conferences.concat( conferences )

					next_token = result["nextToken"]
					break if next_token.nil? || next_token.empty?
				end

				all_conferences
			end

			def fetch_transcript( conference_id )
				all_paragraphs = []
				next_token = nil

				loop do
					params = { direction: "0", maxResults: "200" }
					params[:nextToken] = next_token if next_token

					result = @client.get(
						"/v1.0/conference/videoConferences/#{conference_id}/cloudRecords/getTexts",
						params: params
					)

					paragraphs = result["paragraphList"] || []
					all_paragraphs.concat( paragraphs )

					break unless result["hasMore"]
					next_token = result["nextToken"]
					break if next_token.nil? || next_token.empty?
				end

				all_paragraphs
			rescue StandardError
				# No cloud recording or transcript available
				[]
			end

			def format_meeting( conf, paragraphs )
				lines = []
				lines << "# #{conf["title"] || "无标题会议"}"
				lines << ""
				lines << "- **时间**: #{format_time( conf["startTime"] )}"

				participants = ( conf["userList"] || [] ).map { | u | u["name"] }
				if participants.any?
					lines << "- **参会人**: #{participants.join( "、" )}"
				end
				lines << ""

				if paragraphs.empty?
					lines << "无会议记录。"
				else
					lines << "## 会议记录"
					lines << ""
					paragraphs.each do | para |
						speaker = para["nickName"] || "未知"
						text = para["paragraph"] || ""
						lines << "**#{speaker}**: #{text}"
						lines << ""
					end
				end

				filename = "#{format_date( conf["startTime"] )}-#{sanitize( conf["title"] )}"
				{ filename: filename, content: lines.join( "\n" ) }
			end

			def format_time( ms )
				return "未知" unless ms
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d %H:%M" )
			rescue
				ms.to_s
			end

			def format_date( ms )
				return "unknown" unless ms
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d" )
			rescue
				"unknown"
			end

			def sanitize( name )
				( name || "unknown" ).downcase.gsub( /\s+/, "-" ).gsub( /[^\w\-]/, "" )
			end
		end
	end
end
