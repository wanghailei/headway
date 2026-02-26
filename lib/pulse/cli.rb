# Thor-based CLI. Provides the `run`, `watch`, and `version` commands.

require "thor"

module Pulse
	class CLI < Thor
		desc "run", "Run one collect-synthesise-publish cycle"
		def run_cycle
			config = Config.new
			runner = Runner.new( config )

			puts "Pulse v#{VERSION} — running..."
			runner.run
			puts "Done. Report published."
		end
		map "run" => :run_cycle

		desc "watch", "Run the pipeline on a recurring schedule"
		def watch
			config = Config.new
			mention_queue = Thread::Queue.new
			reply_queue = Thread::Queue.new
			runner = Runner.new( config, mention_queue: mention_queue )
			doc_runner = DocUpdateRunner.new( config )

			stream = nil
			if config.dingtalk_bot_enabled?
				stream = DingTalk::Stream.new(
					app_key: config.dingtalk_app_key,
					app_secret: config.dingtalk_app_secret,
					on_message: ->( msg ) {
						webhook = msg["sessionWebhook"]

						Thread.new do
							report = doc_runner.process( msg )
							if report && webhook
								DingTalk::Stream.reply_via_webhook( webhook,
									msgtype: "text",
									text: { content: "已更新进度报告" }
								)
							else
								mention_queue << msg
								reply_queue << webhook if webhook
							end
						rescue => e
							$stderr.puts "DocUpdateRunner error: #{e.class}: #{e.message}"
							mention_queue << msg
							reply_queue << webhook if webhook
						end
					}
				)
				stream.start
				puts "Pulse v#{VERSION} — bot stream started"
			end

			scheduler = Scheduler.new(
				runner,
				interval_hours: config.interval_hours,
				mention_queue: mention_queue,
				reply_queue: reply_queue
			)

			at_exit { stream&.stop }
			puts "Pulse v#{VERSION} — watching (every #{config.interval_hours}h, Ctrl+C to stop)"
			scheduler.start
		end

		desc "version", "Show version"
		def version
			puts "Pulse v#{VERSION}"
		end
		map "--version" => :version
		map "-v" => :version

		def self.exit_on_failure?
			true
		end
	end
end
