# Recurring scheduler. Runs the collect-synthesise-publish pipeline on
# a fixed interval, handling signals and errors gracefully so the
# process stays alive across individual run failures.

module Pulse
	class Scheduler
		def initialize( runner, interval_hours:, mention_queue: nil, reply_queue: nil, output: $stdout )
			@runner = runner
			@interval_seconds = ( interval_hours * 3600 ).to_i
			@mention_queue = mention_queue
			@reply_queue = reply_queue
			@output = output
			@running = false
		end

		def start
			@running = true
			trap_signals

			log "Scheduler started — running every #{@interval_seconds / 3600.0} hours"

			while @running
				run_once
				break unless @running
				log "Sleeping #{@interval_seconds}s until next run..."
				interruptible_sleep( @interval_seconds )
			end

			log "Scheduler stopped."
		end

		def stop
			@running = false
		end

		def running?
			@running
		end

	private

		def run_once
			timestamp = Time.now.strftime( "%Y-%m-%d %H:%M:%S" )
			log "[#{timestamp}] Run starting..."
			report = @runner.run
			log "[#{timestamp}] Run completed successfully."
			send_replies( report ) if report
		rescue => e
			log "[#{timestamp}] Run failed: #{e.class}: #{e.message}"
		end

		# Drain the reply queue and send the report to each pending
		# sessionWebhook as a markdown message.
		def send_replies( report )
			return unless @reply_queue

			webhooks = []
			webhooks << @reply_queue.pop( true ) until @reply_queue.empty?
			return if webhooks.empty?

			body = {
				msgtype: "markdown",
				markdown: { title: "Pulse Report", text: report }
			}

			webhooks.each do | webhook |
				DingTalk::Stream.reply_via_webhook( webhook, body )
				log "Reply sent to sessionWebhook"
			rescue => e
				log "Failed to send reply: #{e.class}: #{e.message}"
			end
		rescue ThreadError
			# Queue was empty between check and pop — safe to ignore
		end

		def trap_signals
			Signal.trap( "INT" ) do
				@output.write "\nReceived SIGINT — shutting down...\n"
				@running = false
			end

			Signal.trap( "TERM" ) do
				@output.write "\nReceived SIGTERM — shutting down...\n"
				@running = false
			end
		end

		# Sleep in 1-second increments so we can check @running and
		# respond to signal-triggered stops without waiting the full
		# interval. Also wakes up early if a mention arrives in the queue.
		def interruptible_sleep( seconds )
			seconds.times do
				break unless @running
				if @mention_queue && !@mention_queue.empty?
					log "Mention received — triggering immediate run"
					break
				end
				sleep 1
			end
		end

		def log( message )
			@output.puts message
		end
	end
end
