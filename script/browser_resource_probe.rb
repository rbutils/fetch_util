# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "timeout"

usage = "usage: ruby script/browser_resource_probe.rb LIBRARY_ROOT BROWSER_PATH OUTPUT_PATH"
abort usage unless ARGV.length == 3

library_root = File.realpath(ARGV.fetch(0))
library_path = File.file?(File.join(library_root, "fetch_util.rb")) ? library_root : File.join(library_root, "lib")
abort "LIBRARY_ROOT must contain lib/fetch_util.rb" unless File.file?(File.join(library_path, "fetch_util.rb"))

browser_path = File.realpath(ARGV.fetch(1))
abort "BROWSER_PATH must be executable" unless File.file?(browser_path) && File.executable?(browser_path)

output_path = File.expand_path(ARGV.fetch(2))
abort "OUTPUT_PATH parent must already exist" unless File.directory?(File.dirname(output_path))
abort "OUTPUT_PATH already exists" if File.exist?(output_path)

require "tmpdir"
$LOAD_PATH.unshift(library_path)
require "fetch_util"
require "json"

browser_class = FetchUtil::Browser
browser_source = $LOADED_FEATURES.find do |feature|
  File.basename(feature) == "browser.rb" && File.expand_path(feature) == File.join(library_path, "fetch_util", "browser.rb")
end
abort "FetchUtil::Browser was not loaded from LIBRARY_ROOT" unless browser_source

module BrowserResourceProbeFault
  class << self
    attr_accessor :enabled
  end

  module CreatePage
    def create_page(*args, **kwargs)
      page = super
      if BrowserResourceProbeFault.enabled
        page.define_singleton_method(:headers) do
          Object.new.tap do |headers|
            headers.define_singleton_method(:set) do |_value|
              raise IOError, "injected partial setup failure"
            end
          end
        end
      end
      page
    end
  end
end

Ferrum::Browser.prepend(BrowserResourceProbeFault::CreatePage)

def process_tree(root_pid)
  pending = [root_pid]
  found = []
  until pending.empty?
    pid = pending.pop
    next if found.include?(pid) || !File.directory?("/proc/#{pid}")

    found << pid
    Dir.glob("/proc/#{pid}/task/*/children").each do |children|
      pending.concat(File.read(children).split.map(&:to_i))
    rescue Errno::ENOENT, Errno::ESRCH
      next
    end
  end
  found
end

def sample_resources(browser)
  ferrum = browser.instance_variable_get(:@ferrum) || raise("owned Ferrum browser is missing")
  pids = process_tree(ferrum.process.pid)
  rss = pids.sum do |pid|
    status_path = "/proc/#{pid}/status"
    File.file?(status_path) ? (File.read(status_path)[/^VmRSS:\s+(\d+)/, 1] || 0).to_i : 0
  end
  { open_tabs: ferrum.pages.length, process_count: pids.length, process_tree_rss_kib: rss }
end

def settled_resources(browser)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.0
  previous_tabs = nil
  stable_samples = 0
  sample = nil
  loop do
    sample = sample_resources(browser)
    stable_samples = sample[:open_tabs] == previous_tabs ? stable_samples + 1 : 0
    return sample if stable_samples >= 2
    break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    previous_tabs = sample[:open_tabs]
    sleep 0.05
  end
  sample
end

def source_fingerprint(path)
  { path: path, sha256: Digest::SHA256.file(path).hexdigest }
end

ferrum_spec = Gem.loaded_specs.fetch("ferrum")
ferrum_browser_source = Ferrum::Browser.instance_method(:create_page).super_method.source_location.fetch(0)
ferrum_client_source = Ferrum::Client.instance_method(:command).source_location.fetch(0)
browser_version, browser_version_status = Timeout.timeout(5) { Open3.capture2e(browser_path, "--version") }
abort "browser --version failed: #{browser_version.strip}" unless browser_version_status.success?

browser = browser_class.new(browser_path: browser_path, wait: 0, wait_for_idle: false)
abort "Browser selected a different executable" unless File.realpath(browser.instance_variable_get(:@browser_path)) == browser_path

rounds = []
begin
  browser.send(:ensure_browser)
  3.times do |round_index|
    round_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    before = settled_resources(browser)
    fault_count = 0
    fault_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    BrowserResourceProbeFault.enabled = true
    begin
      12.times do
        begin
          browser.with_page("https://example.test/probe-setup-fault") {}
          raise "setup fault unexpectedly succeeded"
        rescue IOError => e
          raise unless e.message == "injected partial setup failure"

          fault_count += 1
        end
      end
    ensure
      BrowserResourceProbeFault.enabled = false
    end
    fault_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - fault_started
    raise "expected exactly 12 setup failures, got #{fault_count}" unless fault_count == 12

    after_faults = settled_resources(browser)
    recovery_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expected_title = "setup-recovery-#{round_index + 1}"
    title = browser.with_page("data:text/html,<title>#{expected_title}</title>") { |page| page.current_title }
    raise "recovery title mismatch: #{title.inspect}" unless title == expected_title

    recovery_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - recovery_started
    after_recovery = settled_resources(browser)
    rounds << {
      round: round_index + 1,
      expected_faults: 12,
      observed_faults: fault_count,
      before: before,
      after_faults: after_faults,
      after_recovery: after_recovery,
      fault_elapsed_seconds: fault_elapsed,
      recovery_elapsed_seconds: recovery_elapsed,
      round_elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - round_started,
      recovery_title: title
    }
  end
  browser.quit
  browser = nil
rescue StandardError
  browser&.quit
  raise
end

browser_dir = File.join(library_path, "fetch_util", "browser")
lifecycle_sources = $LOADED_FEATURES.select do |feature|
  path = File.expand_path(feature)
  path.start_with?("#{browser_dir}/") && File.basename(path).downcase.include?("lifecycle") && File.file?(path)
end.uniq.sort

report = {
  protocol: { rounds: 3, setup_failures_per_round: 12, recovery_requests_per_round: 1, tab_settle_deadline_seconds: 1.0 },
  process_id: Process.pid,
  library_root: library_path,
  source_fingerprints: {
    fetch_util_browser: source_fingerprint(browser_source),
    lifecycle: lifecycle_sources.map { |path| source_fingerprint(path) }
  },
  runtime: {
    ruby_version: RUBY_VERSION,
    ruby_executable: source_fingerprint(File.realpath(RbConfig.ruby)),
    ferrum_version: ferrum_spec.version.to_s,
    ferrum_gem_path: ferrum_spec.full_gem_path,
    ferrum_browser_source: source_fingerprint(File.realpath(ferrum_browser_source)),
    ferrum_client_source: source_fingerprint(File.realpath(ferrum_client_source)),
    browser_path: browser_path,
    browser_sha256: Digest::SHA256.file(browser_path).hexdigest,
    browser_version: browser_version.strip
  },
  rounds: rounds
}

File.write(output_path, "#{JSON.pretty_generate(report)}\n")
puts "wrote #{output_path} (#{rounds.length} rounds, #{rounds.sum { |round| round[:observed_faults] }} injected failures)"
