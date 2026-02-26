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
			runner = Runner.new( config )
			scheduler = Scheduler.new( runner, interval_hours: config.interval_hours )

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
