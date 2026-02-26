# Tests for Pulse::Scheduler. Verifies the run loop, error resilience,
# signal-triggered shutdown, and logging using a fake runner and captured output.

require "test_helper"
require "stringio"

class TestScheduler < Minitest::Test
	def test_runs_pipeline_and_stops
		runner = CountingRunner.new( stop_after: 2 )
		output = StringIO.new
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 0, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_equal 2, runner.run_count
		assert_includes output.string, "Run completed successfully"
		assert_includes output.string, "Scheduler stopped"
	end

	def test_survives_run_failure
		runner = FailThenSucceedRunner.new
		output = StringIO.new
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 0, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_equal 2, runner.run_count
		assert_includes output.string, "Run failed: RuntimeError: boom"
		assert_includes output.string, "Run completed successfully"
	end

	def test_logs_start_and_stop
		runner = CountingRunner.new( stop_after: 1 )
		output = StringIO.new
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 1, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_includes output.string, "Scheduler started"
		assert_includes output.string, "Scheduler stopped"
	end

	def test_stop_sets_running_to_false
		runner = CountingRunner.new( stop_after: 1 )
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 0, output: StringIO.new )
		runner.scheduler = scheduler
		scheduler.start

		refute scheduler.running?
	end

	def test_mention_triggers_immediate_run
		queue = Thread::Queue.new
		runner = CountingRunner.new( stop_after: 2 )
		output = StringIO.new
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 24, mention_queue: queue, output: output )
		runner.scheduler = scheduler

		# After first run, push a mention to wake up the sleep
		original_run = runner.method( :run )
		runner.define_singleton_method( :run ) do
			original_run.call
			queue << { "text" => "hello" } if run_count == 1
		end

		scheduler.start

		assert_equal 2, runner.run_count
		assert_includes output.string, "Mention received"
	end

	def test_interval_converts_hours_to_seconds
		runner = CountingRunner.new( stop_after: 1 )
		output = StringIO.new
		scheduler = Pulse::Scheduler.new( runner, interval_hours: 2, output: output )
		runner.scheduler = scheduler
		scheduler.start

		assert_includes output.string, "every 2.0 hours"
	end

	def test_reply_queue_sends_report_after_run
		reply_queue = Thread::Queue.new
		reply_queue << "https://example.com/webhook1"
		reply_queue << "https://example.com/webhook2"

		runner = ReportRunner.new( report: "# Test Report", stop_after: 1 )
		output = StringIO.new
		scheduler = Pulse::Scheduler.new(
			runner,
			interval_hours: 0,
			reply_queue: reply_queue,
			output: output
		)
		runner.scheduler = scheduler

		sent = []
		original = Pulse::DingTalk::Stream.method( :reply_via_webhook )
		Pulse::DingTalk::Stream.define_singleton_method( :reply_via_webhook ) do | url, body |
			sent << [ url, body ]
		end
		begin
			scheduler.start
		ensure
			Pulse::DingTalk::Stream.define_singleton_method( :reply_via_webhook, original )
		end

		assert_equal 2, sent.length
		assert_equal "https://example.com/webhook1", sent[0][0]
		assert_equal "https://example.com/webhook2", sent[1][0]
		assert_equal "markdown", sent[0][1][:msgtype]
		assert_equal "# Test Report", sent[0][1][:markdown][:text]
		assert_includes output.string, "Reply sent to sessionWebhook"
	end

	def test_reply_queue_not_sent_on_run_failure
		reply_queue = Thread::Queue.new
		reply_queue << "https://example.com/webhook"

		runner = FailThenSucceedRunner.new
		output = StringIO.new
		scheduler = Pulse::Scheduler.new(
			runner,
			interval_hours: 0,
			reply_queue: reply_queue,
			output: output
		)
		runner.scheduler = scheduler

		sent = []
		original = Pulse::DingTalk::Stream.method( :reply_via_webhook )
		Pulse::DingTalk::Stream.define_singleton_method( :reply_via_webhook ) do | url, body |
			sent << [ url, body ]
		end
		begin
			scheduler.start
		ensure
			Pulse::DingTalk::Stream.define_singleton_method( :reply_via_webhook, original )
		end

		# First run fails (no reply sent), second succeeds (reply sent)
		assert_equal 1, sent.length
		assert_equal "https://example.com/webhook", sent[0][0]
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
		"fake report"
	end
end

# Fake runner that returns a specific report string.
class ReportRunner
	attr_reader :run_count
	attr_accessor :scheduler

	def initialize( report:, stop_after: )
		@report = report
		@stop_after = stop_after
		@run_count = 0
	end

	def run
		@run_count += 1
		scheduler.stop if @run_count >= @stop_after
		@report
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
			"recovered report"
		end
	end
end
