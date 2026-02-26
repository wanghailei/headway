# Pipeline orchestrator. Ties together the full workflow: collect items
# from configured sources, synthesize via AI, render the report
# template, and publish to configured destinations.

module Pulse
	class Runner
		def initialize( config, ai_client: nil, template_path: "templates/report.md.erb", mention_queue: nil )
			@config = config
			@ai_client = ai_client || build_ai_client
			@template_path = template_path
			@mention_queue = mention_queue
		end

		def run
			items = collect
			body = synthesize( items )
			report = render( body )
			publish( report )
			report
		end

		def self.find_previous_report( publishers )
			output_dir = publishers
				.select { | p | p["type"] == "markdown_file" }
				.map { | p | p["path"] }
				.first

			return nil unless output_dir && File.directory?( output_dir )

			reports = Dir.glob( File.join( output_dir, "RP.*.md" ) ).sort
			return nil if reports.empty?

			File.read( reports.last, encoding: "UTF-8" )
		end

	private

		def collect
			items = []
			@config.collectors.each do | c |
				case c["type"]
				when "local_files"
					items.concat Collectors::LocalFiles.new( c["path"] ).collect
				when "dingtalk_reports"
					items.concat Collectors::DingtalkReports.new(
						client: dingtalk_client,
						interval_hours: @config.interval_hours,
						template_name: c["template_name"]
					).collect
				when "dingtalk_todos"
					items.concat Collectors::DingtalkTodos.new(
						client: dingtalk_client
					).collect
				when "dingtalk_meetings"
					items.concat Collectors::DingtalkMeetings.new(
						client: dingtalk_client,
						interval_hours: @config.interval_hours
					).collect
				when "dingtalk_mentions"
					if @mention_queue
						items.concat Collectors::DingtalkMentions.new(
							queue: @mention_queue,
							doc_reader: build_doc_reader
						).collect
					end
				end
			end
			items
		end

		def synthesize( items )
			previous = find_previous_report
			Synthesizer.new( @ai_client, previous_report: previous ).synthesize( items )
		end

		def find_previous_report
			self.class.find_previous_report( @config.publishers )
		end

		def render( body )
			ReportRenderer.new( @template_path ).render(
				date: Time.now.strftime( "%Y-%m-%d" ),
				body: body
			)
		end

		def publish( report )
			@config.publishers.each do | p |
				case p["type"]
				when "markdown_file"
					Publishers::MarkdownFile.new( p["path"] ).publish( report )
				when "dingtalk_doc"
					Publishers::DingtalkDoc.new(
						client: dingtalk_client,
						space_id: p["space_id"],
						doc_id: p["doc_id"],
						operator_user_id: p["operator_user_id"]
					).publish( report )
				when "dingtalk_bot_notify"
					Publishers::DingtalkBotNotify.new(
						messenger: bot_messenger,
						user_ids: @config.dingtalk_bot_notify_user_ids,
						report_url: p["report_url"]
					).publish( report )
				end
			end
		end

		def dingtalk_client
			@dingtalk_client ||= DingTalk::Client.new(
				app_key: @config.dingtalk_app_key,
				app_secret: @config.dingtalk_app_secret
			)
		end

		def build_doc_reader
			DingTalk::DocReader.new( client: dingtalk_client )
		end

		def bot_messenger
			@bot_messenger ||= DingTalk::BotMessenger.new(
				client: dingtalk_client,
				robot_code: @config.dingtalk_robot_code
			)
		end

		def build_ai_client
			# When the key came from Codex CLI OAuth, use the Responses
			# API which is covered by ChatGPT Pro subscriptions.
			client_class = @config.using_codex_auth? ? ResponsesClient : AIClient
			client_class.new(
				base_url: @config.ai_base_url,
				api_key: @config.ai_api_key,
				model: @config.ai_model
			)
		end
	end
end
