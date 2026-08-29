# frozen_string_literal: true

require "rake"

RSpec.describe "Rake tasks" do
  around do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path("../Rakefile", __dir__)
    example.run
  ensure
    Rake.application = original_application
  end

  it "checks asset freshness before tasks that rebuild the bundle" do
    expect(Rake::Task["verify_extract_assets"].prerequisites).to be_empty
    expect(Rake::Task["spec"].prerequisites).to include("build_extract_assets")
    expect(Rake::Task["build"].prerequisites).to include("build_extract_assets")
    expect(Rake::Task["release"].prerequisites).to include("build_extract_assets")
    expect(Rake::Task["default"].prerequisites).to eq(%w[verify_extract_assets spec rubocop])
  end
end
