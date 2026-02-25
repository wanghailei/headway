# DingTalk Todos (待办) collector. Reads pending tasks from the
# DingTalk Todo API. Tasks are sorted by due date (earliest first)
# so the most urgent items appear at the top of the briefing.

module Headway
	module Collectors
		class DingtalkTodos
			PRIORITY_LABELS = {
				10 => "Urgent",
				20 => "High",
				30 => "Medium",
				40 => "Low"
			}.freeze

			def initialize( client:, operator_user_id: )
				@client = client
				@operator_user_id = operator_user_id
			end

			def collect
				tasks = fetch_tasks
				return [] if tasks.empty?

				files = tasks
					.sort_by do | task |
						task["dueTime"] || Float::INFINITY
					end
					.map do | task |
						format_task( task )
					end

				[ { name: "Tasks", files: files } ]
			end

		private

			def fetch_tasks
				result = @client.post(
					"/v1.0/todo/users/#{@operator_user_id}/tasks/query",
					body: { isDone: false }
				)
				result["todoCards"] || []
			end

			def format_task( task )
				lines = []
				lines << "# #{task["subject"]}"
				lines << ""
				lines << "- **Status**: #{task["isDone"] ? "Done" : "Pending"}"
				lines << "- **Due**: #{format_date( task["dueTime"] )}" if task["dueTime"]
				lines << "- **Priority**: #{priority_label( task["priority"] )}"
				lines << ""

				if task["description"] && !task["description"].empty?
					lines << task["description"]
				end

				filename = "#{format_date( task["dueTime"] )}-#{sanitize( task["subject"] )}"
				{ filename: filename, content: lines.join( "\n" ) }
			end

			def priority_label( level )
				PRIORITY_LABELS[level] || "Unknown"
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
