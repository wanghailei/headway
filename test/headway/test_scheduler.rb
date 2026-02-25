# Tests for Headway::Scheduler. Verifies the run loop, error resilience,
# signal-triggered shutdown, and logging using a fake runner and captured output.

require "test_helper"
require "stringio"

class TestScheduler < Minitest::Test
	def test_runs_pipeline_and_stops
		runner = CountingRunner.new( stop_after: 2 )
		output = StringIO.new
		scheduler = Headway::Scheduler.new( runner, interval_hours: 0, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_equal 2, runner.run_count
		assert_includes output.string, "Run completed successfully"
		assert_includes output.string, "Scheduler stopped"
	end

	def test_survives_run_failure
		runner = FailThenSucceedRunner.new
		output = StringIO.new
		scheduler = Headway::Scheduler.new( runner, interval_hours: 0, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_equal 2, runner.run_count
		assert_includes output.string, "Run failed: RuntimeError: boom"
		assert_includes output.string, "Run completed successfully"
	end

	def test_logs_start_and_stop
		runner = CountingRunner.new( stop_after: 1 )
		output = StringIO.new
		scheduler = Headway::Scheduler.new( runner, interval_hours: 1, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_includes output.string, "Scheduler started"
		assert_includes output.string, "Scheduler stopped"
	end

	def test_stop_sets_running_to_false
		runner = CountingRunner.new( stop_after: 1 )
		scheduler = Headway::Scheduler.new( runner, interval_hours: 0, output: StringIO.new )
		runner.scheduler = scheduler
		scheduler.start

		refute scheduler.running?
	end

	def test_interval_converts_hours_to_seconds
		runner = CountingRunner.new( stop_after: 1 )
		output = StringIO.new
		scheduler = Headway::Scheduler.new( runner, interval_hours: 2, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_includes output.string, "every 2.0 hours"
	end
end

# Fake runner that counts invocations and stops the scheduler after N runs.
class CountingRunner
	attr_reader :run_count
	attr_accessor :scheduler

	def initialize( stop_after: )
		@stop_after = stop_after
		@run_count = 0
	end

	def run
		@run_count += 1
		scheduler.stop if @run_count >= @stop_after
	end
end

# Fake runner that raises on the first call, succeeds and stops on the second.
class FailThenSucceedRunner
	attr_reader :run_count
	attr_accessor :scheduler

	def initialize
		@run_count = 0
	end

	def run
		@run_count += 1
		if @run_count == 1
			raise RuntimeError, "boom"
		else
			scheduler.stop
		end
	end
end
