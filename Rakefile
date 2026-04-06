# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task :build_extract_assets do
  ruby "script/build_extract_assets.rb"
end

task :verify_extract_assets do
  ruby "script/build_extract_assets.rb", "--check"
end

task default: %i[verify_extract_assets spec rubocop]
