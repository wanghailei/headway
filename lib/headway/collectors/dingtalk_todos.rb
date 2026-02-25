# DingTalk Todos (待办) collector. Reads pending tasks from all
# employees via the DingTalk Todo API. Iterates over every employee
# in the organisation, queries their pending todos, and groups them
# into a single "Tasks" section sorted by due date (earliest first).

module Headway
	module Collectors
		class DingtalkTodos
			PRIORITY_LABELS = {
				10 => "紧急",
				20 => "高",
				30 => "中",
				40 => "低"
			}.freeze

			def initialize( client: )
				@client = client
			end

			def collect
				tasks = fetch_all_tasks
				return [] if tasks.empty?

				files = tasks
					.sort_by do | task |
						task[:due] || Float::INFINITY
					end
					.map do | task |
						task[:formatted]
					end

				[ { name: "Tasks", files: files } ]
			end

		private

			def fetch_all_tasks
				employees = @client.list_employees
				all_tasks = []

				employees.each do | emp |
					next unless emp[:unionid]

					begin
						result = @client.post(
							"/v1.0/todo/users/#{emp[:unionid]}/org/tasks/query",
							body: { isDone: false }
						)
						cards = result["todoCards"] || []
						cards.each do | task |
							all_tasks << {
								due: task["dueTime"],
								formatted: format_task( task, emp[:name] )
							}
						end
					rescue StandardError
						# Skip employees whose todos can't be read
						next
					end
				end

				all_tasks
			end

			def format_task( task, owner_name )
				lines = []
				lines << "# #{task["subject"]}"
				lines << ""
				lines << "- **负责人**: #{owner_name}"
				lines << "- **状态**: #{task["isDone"] ? "已完成" : "待办"}"
				lines << "- **截止**: #{format_date( task["dueTime"] )}" if task["dueTime"]
				lines << "- **优先级**: #{priority_label( task["priority"] )}"
				lines << ""

				if task["description"] && !task["description"].empty?
					lines << task["description"]
				end

				filename = "#{format_date( task["dueTime"] )}-#{sanitize( task["subject"] )}"
				{ filename: filename, content: lines.join( "\n" ) }
			end

			def priority_label( level )
				PRIORITY_LABELS[level] || "未知"
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
