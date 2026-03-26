# frozen_string_literal: true

require_relative 'lib/fetch_util/version'

Gem::Specification.new do |spec|
  spec.name = 'fetch_util'
  spec.version = FetchUtil::VERSION
  spec.authors = ['hmdne']
  spec.email = ['54514036+hmdne@users.noreply.github.com']

  spec.summary = 'AI for fetching in Ruby'
  spec.description = 'An intelligent web-fetch engine for Ruby that renders live pages, recognizes what they are, and turns them into clean, usable markdown.'
  spec.homepage = 'https://github.com/rbutils/fetch_util'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['source_code_uri'] = 'https://github.com/rbutils/fetch_util'
  spec.metadata['changelog_uri'] = 'https://github.com/rbutils/fetch_util/blob/master/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/rbutils/fetch_util#readme'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/rbutils/fetch_util/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  tracked_files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL, &:read)&.split("\x0")
  tracked_files&.reject!(&:empty?)
  if tracked_files.nil? || tracked_files.empty?
    tracked_files = Dir.glob("**/*", File::FNM_DOTMATCH, base: __dir__).select do |file|
      next false if %w[. ..].include?(file)

      File.file?(File.join(__dir__, file))
    end
  end
  built_asset = 'lib/fetch_util/assets/extract.js'
  tracked_files |= [built_asset] if File.file?(File.join(__dir__, built_asset))

  spec.files = tracked_files.reject do |file|
    (file == gemspec) || file.end_with?(".gem") || file.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile coverage/ pkg/ tmp/ .bundle/ .ruby-lsp/ 
                                                                        script/ lib/fetch_util/assets/src/])
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |file| File.basename(file) }
  spec.require_paths = ['lib']

  spec.add_dependency 'ferrum', '~> 0.17'
  spec.add_dependency 'nokogiri', '~> 1.19'
  spec.add_dependency 'thor', '~> 1.3'
end
