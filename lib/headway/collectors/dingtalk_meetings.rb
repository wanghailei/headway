# DingTalk Meeting Notes collector. Reads meeting transcripts from
# DingTalk's cloud recording feature. For each recent meeting, fetches
# the recording details and transcribed text, then formats them as
# structured markdown for the briefing.

module Headway
	module Collectors
		class DingtalkMeetings
			def initialize( client:, interval_hours: 2 )
				@client = client
				@interval_hours = interval_hours
			end

			def collect
				conferences = fetch_conferences
				return [] if conferences.empty?

				files = conferences.map do | conference |
					transcript = fetch_transcript( conference["conferenceId"] )
					format_meeting( conference, transcript )
				end

				[ { name: "Meeting Notes", files: files } ]
			end

		private

			def fetch_conferences
				now = ( Time.now.to_f * 1000 ).to_i
				start = now - ( @interval_hours * 3600 * 1000 )

				result = @client.post(
					"/v1.0/conference/videoConferences/query",
					body: { startTime: start, endTime: now }
				)
				result["conferenceList"] || []
			end

			def fetch_transcript( conference_id )
				result = @client.get(
					"/v1.0/conference/videoConferences/#{conference_id}/recordings/transcripts"
				)
				result["paragraphList"] || []
			end

			def format_meeting( conference, paragraphs )
				lines = []
				lines << "# #{conference["title"]}"
				lines << ""
				lines << "- **Date**: #{format_time( conference["startTime"] )}"
				participants = ( conference["userList"] || [] ).map do | u |
					u["name"]
				end
				lines << "- **Participants**: #{participants.join( ", " )}"
				lines << ""
				lines << "## Transcript"
				lines << ""

				if paragraphs.empty?
					lines << "No transcript available."
				else
					paragraphs.each do | para |
						lines << "**#{para["speakerName"]}**: #{para["paragraphContent"]}"
						lines << ""
					end
				end

				filename = "#{format_date( conference["startTime"] )}-#{sanitize( conference["title"] )}"
				{ filename: filename, content: lines.join( "\n" ) }
			end

			def format_time( ms )
				Time.at( ms / 1000 ).strftime( "%Y-%m-%d %H:%M" )
			rescue
				ms.to_s
			end

			def format_date( ms )
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
