# DingTalk Reports (日志) collector. Reads employee daily/weekly work
# reports via the legacy DingTalk API. Reports are the primary progress
# data source — employees already submit these to their managers.

module Pulse
	module Collectors
		class DingtalkReports
			def initialize( client:, interval_hours: 2, template_name: nil )
				@client = client
				@interval_hours = interval_hours
				@template_name = template_name
			end

			def collect
				reports = fetch_reports
				return [] if reports.empty?

				files = reports.map do | report |
					format_report( report )
				end

				[ { name: "Reports", files: files } ]
			end

		private

			def fetch_reports
				now = ( Time.now.to_f * 1000 ).to_i
				start = now - ( @interval_hours * 3600 * 1000 )

				all_reports = []
				cursor = 0

				loop do
					body = {
						start_time: start,
						end_time: now,
						cursor: cursor,
						size: 20
					}
					body[:template_name] = @template_name if @template_name

					result = @client.legacy_post( "/topapi/report/list", body: body )
					data = result.dig( "result", "data_list" ) || []
					all_reports.concat( data )

					break unless result.dig( "result", "has_more" )
					cursor = result.dig( "result", "next_cursor" ) || 0
				end

				all_reports
			end

			def format_report( report )
				lines = []
				lines << "# #{report["template_name"]} — #{report["creator_name"]}"
				lines << ""
				lines << "- **Submitted**: #{format_time( report["create_time"] )}"
				lines << ""

				contents = report["contents"] || []
				contents.each do | field |
					lines << "## #{field["key"]}"
					lines << ""
					lines << field["value"].to_s
					lines << ""
				end

				if report["remark"] && !report["remark"].empty?
					lines << "## Remark"
					lines << ""
					lines << report["remark"]
				end

				filename = "#{format_date( report["create_time"] )}-#{sanitize( report["creator_name"] )}"
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
