# frozen_string_literal: true

require_relative "process_inspector"

module NativeReplay
  module ProcessSupervisor
    POLL_INTERVAL = 0.05
    TERM_GRACE_SECONDS = 0.5
    KILL_WAIT_SECONDS = 2

    module_function

    def ensure_supported!
      ProcessInspector.ensure_supported!
    end

    def process_group(pid)
      ProcessInspector.process_group(pid)
    end

    def descendant_groups(root_pid)
      ProcessInspector.descendant_groups(root_pid)
    end

    def live_members(group)
      ProcessInspector.live_members(group)
    end

    def terminate_tree(root_pid, known_groups = [])
      groups = known_groups.dup
      term_signaled = []
      term_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TERM_GRACE_SECONDS
      loop do
        groups = merge_groups(groups, ProcessInspector.descendant_groups(root_pid))
        groups.each do |group|
          next if term_signaled.include?(group.fetch("pgid"))

          signal_group(group, "TERM")
          term_signaled << group.fetch("pgid")
        end
        break if groups.all? { |group| live_members(group).empty? }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= term_deadline

        sleep POLL_INTERVAL
      end

      groups = merge_groups(groups, ProcessInspector.descendant_groups(root_pid))
      groups.each { |group| signal_group(group, "KILL") unless live_members(group).empty? }
      wait_for_exit(groups, KILL_WAIT_SECONDS)
      survivors = groups.flat_map { |group| live_members(group).map { |member| member.fetch("pid") } }.uniq
      raise "process groups remain after KILL: #{survivors.join(",")}" unless survivors.empty?

      groups
    end

    def wait_for_exit(groups, seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        return if groups.all? { |group| ProcessInspector.live_members(group).empty? }

        sleep POLL_INTERVAL
      end
    end

    def signal_group(group, signal)
      return if ProcessInspector.live_members(group).empty?

      leader = ProcessInspector.process(group.fetch("pid"))
      if leader && leader.fetch("start_time_ticks") == group.fetch("start_time_ticks") &&
         leader.fetch("pgid") == group.fetch("pgid")
        Process.kill(signal, -group.fetch("pgid"))
      else
        group.fetch("members", []).each do |member|
          current = ProcessInspector.process(member.fetch("pid"))
          next unless current && current.fetch("start_time_ticks") == member.fetch("start_time_ticks") &&
                      current.fetch("pgid") == group.fetch("pgid") && current.fetch("state") != "Z"

          Process.kill(signal, member.fetch("pid"))
        end
      end
    rescue Errno::ESRCH
      nil
    end

    def merge_groups(existing, updates)
      (existing + updates).group_by { |group| group.fetch("pgid") }.map do |_pgid, records|
        records.first.merge("members" => records.flat_map { |record| record.fetch("members", []) }.uniq { |member| member.fetch("pid") })
      end
    end

    private_class_method :wait_for_exit, :signal_group, :merge_groups
  end
end
