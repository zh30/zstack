# frozen_string_literal: true

require "thread"

module Zstack
  module EvalResourceMonitor
    class Batch
      def initialize(checks, poll_seconds:, shared_check: nil, &terminate)
        raise ArgumentError, "resource terminator is required" unless terminate

        @targets = checks.to_h do |pid, check|
          raise ArgumentError, "resource check must be callable for pid #{pid}" unless check.respond_to?(:call)

          [pid, { check: check, active: true, error: nil }]
        end
        @poll_seconds = poll_seconds
        unless shared_check.nil? || shared_check.respond_to?(:call)
          raise ArgumentError, "shared resource check must be callable"
        end
        @shared_check = shared_check
        @shared_error = nil
        @terminate = terminate
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @stopped = false
        @thread = nil
      end

      def add(pid, check)
        raise ArgumentError, "resource check must be callable for pid #{pid}" unless check.respond_to?(:call)

        @mutex.synchronize do
          raise "resource monitor must be started before adding targets" unless @thread
          raise "resource monitor is stopped" if @stopped
          raise "resource monitor already has pid #{pid}" if @targets.key?(pid)

          @targets[pid] = { check: check, active: true, error: nil }
          @condition.broadcast
        end
        self
      end

      def start
        @mutex.synchronize do
          raise "resource monitor already started" if @thread

          @thread = Thread.new { monitor }
        end
        self
      end

      def check_now(pid)
        shared_error, = evaluate_shared
        return shared_error if shared_error

        error, = evaluate(pid)
        error
      end

      def finish(pid)
        @mutex.synchronize do
          target = @targets.fetch(pid)
          @shared_error ||= safe_check(@shared_check) if @shared_check
          error = @shared_error || target[:error] || safe_check(target.fetch(:check))
          target[:error] ||= error
          target[:active] = false
          error
        end
      end

      def stop
        thread = @mutex.synchronize do
          @stopped = true
          @condition.broadcast
          @thread
        end
        thread&.join
      ensure
        @thread = nil
      end

      private

      def monitor
        loop do
          pids = @mutex.synchronize do
            unless @stopped
              @targets.each_with_object([]) do |(pid, target), active|
                active << pid if target[:active] && target[:error].nil?
              end
            end
          end
          break unless pids

          unless pids.empty?
            shared_error, shared_newly_recorded = evaluate_shared
            if shared_newly_recorded
              pids.each { |pid| safely_terminate(pid) }
            elsif shared_error.nil?
              pids.each do |pid|
                _error, newly_recorded = evaluate(pid)
                safely_terminate(pid) if newly_recorded
              end
            end
          end
          stopped = @mutex.synchronize do
            @condition.wait(@mutex, @poll_seconds) unless @stopped
            @stopped
          end
          break if stopped
        end
      rescue StandardError => e
        fail_all_active("batch resource monitor failed safely: #{e.class}")
      end

      def evaluate(pid)
        @mutex.synchronize do
          target = @targets.fetch(pid)
          return [target[:error], false] unless target[:active] && target[:error].nil?

          error = safe_check(target.fetch(:check))
          target[:error] = error if error
          [error, !error.nil?]
        end
      end

      def evaluate_shared
        @mutex.synchronize do
          return [@shared_error, false] if @shared_check.nil? || @shared_error

          error = safe_check(@shared_check)
          @shared_error = error if error
          [error, !error.nil?]
        end
      end

      def safe_check(check)
        result = check.call
        return nil if result.nil? || (result.is_a?(String) && result.empty?)

        result.to_s
      rescue StandardError => e
        "resource monitor failed safely: #{e.class}"
      end

      def fail_all_active(error)
        pids = @mutex.synchronize do
          @targets.each_with_object([]) do |(pid, target), active|
            next unless target[:active]

            target[:error] ||= error
            active << pid
          end
        end
        pids.each { |pid| safely_terminate(pid) }
      rescue StandardError
        nil
      end

      def safely_terminate(pid)
        @terminate.call(pid)
      rescue StandardError
        # The parent wait path will retry termination after reading the
        # recorded error, so one failed signal must not stop the monitor.
        nil
      end
    end
  end
end
