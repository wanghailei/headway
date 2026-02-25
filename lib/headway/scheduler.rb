# Recurring scheduler for Headway. Runs the collect-synthesise-publish
# pipeline on a fixed interval, handling signals and errors gracefully
# so the process stays alive across individual run failures.

module Headway
	class Scheduler
		def initialize( runner, interval_hours:, output: $stdout )
			@runner = runner
			@interval_seconds = ( interval_hours * 3600 ).to_i
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
			@runner.run
			log "[#{timestamp}] Run completed successfully."
		rescue => e
			log "[#{timestamp}] Run failed: #{e.class}: #{e.message}"
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
		# interval.
		def interruptible_sleep( seconds )
			seconds.times do
				break unless @running
				sleep 1
			end
		end

		def log( message )
			@output.puts message
		end
	end
end
