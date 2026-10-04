# frozen_string_literal: true

module NativeReplay
  module ProcessInspector
    module_function

    def ensure_supported!
      raise "native replay watchdog requires Linux /proc" unless RUBY_PLATFORM.include?("linux") && File.directory?("/proc/self")
    end

    def process_group(pid)
      entry = read_process(pid)
      raise "process #{pid} is unavailable in /proc" unless entry
      raise "process #{pid} is not its process-group leader" unless entry.fetch("pgid") == pid

      group_record(entry)
    end

    def descendant_groups(root_pid)
      entries = process_table
      by_pid = entries.to_h { |entry| [entry.fetch("pid"), entry] }
      children = entries.group_by { |entry| entry.fetch("ppid") }
      descendants = []
      frontier = [root_pid]
      until frontier.empty?
        descendants.concat(frontier)
        frontier = frontier.flat_map { |pid| children.fetch(pid, []).map { |entry| entry.fetch("pid") } }
        frontier -= descendants
      end
      groups = descendants.filter_map do |pid|
        entry = by_pid[pid]
        next unless entry

        leader = by_pid[entry.fetch("pgid")] || read_process(entry.fetch("pgid"))
        next unless leader && leader.fetch("pgid") == entry.fetch("pgid")

        group_record(leader).merge("members" => [])
      end
      groups.each do |group|
        group["members"] = descendants.filter_map do |pid|
          entry = by_pid[pid]
          entry.slice("pid", "start_time_ticks") if entry && entry.fetch("pgid") == group.fetch("pgid")
        end.uniq { |member| member.fetch("pid") }
      end
      groups.uniq { |group| group.fetch("pgid") }
    end

    def live_members(group)
      process_table.select { |entry| entry.fetch("pgid") == group.fetch("pgid") && entry.fetch("state") != "Z" }
    end

    def process(pid)
      read_process(pid)
    end

    def read_process(pid)
      stat = File.read("/proc/#{pid}/stat")
      fields = stat[(stat.rindex(")") + 2)..].split
      {
        "pid" => pid, "state" => fields.fetch(0), "ppid" => fields.fetch(1).to_i,
        "pgid" => fields.fetch(2).to_i, "start_time_ticks" => fields.fetch(19),
        "executable" => File.readlink("/proc/#{pid}/exe")
      }
    rescue Errno::ENOENT, Errno::ESRCH, Errno::EACCES
      nil
    end

    def process_table
      Dir.children("/proc").filter_map do |name|
        read_process(name.to_i) if name.match?(/\A\d+\z/)
      end
    end

    def group_record(entry)
      entry.slice("pid", "pgid", "start_time_ticks", "executable")
    end

    private_class_method :read_process, :process_table, :group_record
  end
end
