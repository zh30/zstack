# Frozen process supervision helpers shared by real-host evaluation runners.

require_relative "eval_limits"

module Zstack
  module EvalProcessSupervisor
    POLL_SECONDS = 0.05
    RESOURCE_POLL_SECONDS = 0.25
    # Timed-out or orphaned process groups get only a narrow cooperative-exit
    # window before SIGKILL so background work cannot keep mutating the run.
    TERM_GRACE_SECONDS = 0.1
    MAX_HOST_OUTPUT_BYTES = EvalLimits::MAX_HOST_OUTPUT_BYTES

    module_function

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def wait(pid, started_at:, timeout_seconds:, output_paths: [], max_output_bytes: MAX_HOST_OUTPUT_BYTES, resource_check: nil)
      next_resource_check = started_at
      loop do
        waited = Process.wait2(pid, Process::WNOHANG)
        if waited
          terminate_remaining_group(pid)
          output_limited = output_bytes(output_paths) > max_output_bytes
          return [waited.fetch(1), false, true] if output_limited

          final_resource_error = resource_error(resource_check)
          return [waited.fetch(1), false, false, final_resource_error] if final_resource_error

          return [waited.fetch(1), false, false]
        end

        if output_bytes(output_paths) > max_output_bytes
          return [terminate_and_wait(pid), false, true]
        end

        now = monotonic_time
        if resource_check && now >= next_resource_check
          current_resource_error = resource_error(resource_check)
          return [terminate_and_wait(pid), false, false, current_resource_error] if current_resource_error

          next_resource_check = now + RESOURCE_POLL_SECONDS
        end

        remaining = timeout_seconds - (now - started_at)
        if remaining <= 0
          return [terminate_and_wait(pid), true, false]
        end

        sleep([POLL_SECONDS, remaining].min)
      end
    end

    def output_bytes(paths)
      Array(paths).compact.uniq.inject(0) do |total, path|
        stat = File.lstat(path)
        total + (stat.file? ? stat.size : 0)
      rescue Errno::ENOENT, Errno::EACCES
        total
      end
    end

    def resource_error(check)
      return nil unless check

      result = check.call
      return nil if result.nil? || (result.is_a?(String) && result.empty?)

      result.to_s
    rescue StandardError => e
      "resource monitor failed safely: #{e.class}"
    end
    private_class_method :resource_error

    def terminate_and_reap(pid)
      terminate_and_wait(pid)
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end

    def terminate_without_reap(pid)
      signal_group("TERM", pid)
      deadline = monotonic_time + TERM_GRACE_SECONDS
      while process_group_alive?(pid) && monotonic_time < deadline
        sleep(POLL_SECONDS)
      end
      signal_group("KILL", pid) if process_group_alive?(pid)
      nil
    rescue Errno::ESRCH
      nil
    end

    def exit_status(status)
      status.exitstatus || 128 + status.termsig
    end

    def terminate_and_wait(pid)
      signal_group("TERM", pid)
      deadline = monotonic_time + TERM_GRACE_SECONDS
      loop do
        waited = Process.wait2(pid, Process::WNOHANG)
        if waited
          terminate_remaining_group(pid, deadline: deadline, term_already_sent: true)
          return waited.fetch(1)
        end
        break if monotonic_time >= deadline

        sleep(POLL_SECONDS)
      end

      signal_group("KILL", pid)
      Process.wait2(pid).fetch(1)
    end
    private_class_method :terminate_and_wait

    def terminate_remaining_group(pid, deadline: monotonic_time + TERM_GRACE_SECONDS, term_already_sent: false)
      signal_group("TERM", pid) unless term_already_sent
      while process_group_alive?(pid) && monotonic_time < deadline
        sleep(POLL_SECONDS)
      end
      signal_group("KILL", pid) if process_group_alive?(pid)
    end
    private_class_method :terminate_remaining_group

    def process_group_alive?(pid)
      Process.kill(0, -pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
    private_class_method :process_group_alive?

    def signal_group(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH
      nil
    rescue Errno::EPERM
      begin
        Process.kill(signal, pid)
      rescue Errno::ESRCH
        nil
      end
    end
    private_class_method :signal_group
  end
end
