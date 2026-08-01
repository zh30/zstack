# Frozen process supervision helpers shared by real-host evaluation runners.

module Zstack
  module EvalProcessSupervisor
    POLL_SECONDS = 0.05
    TERM_GRACE_SECONDS = 1.0

    module_function

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def wait(pid, started_at:, timeout_seconds:)
      loop do
        waited = Process.wait2(pid, Process::WNOHANG)
        return [waited.fetch(1), false] if waited

        remaining = timeout_seconds - (monotonic_time - started_at)
        if remaining <= 0
          return [terminate_and_wait(pid), true]
        end

        sleep([POLL_SECONDS, remaining].min)
      end
    end

    def terminate_and_reap(pid)
      terminate_and_wait(pid)
    rescue Errno::ECHILD, Errno::ESRCH
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
        return waited.fetch(1) if waited
        break if monotonic_time >= deadline

        sleep(POLL_SECONDS)
      end

      signal_group("KILL", pid)
      Process.wait2(pid).fetch(1)
    end
    private_class_method :terminate_and_wait

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
