# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Described image resources' do
  include_context 'extractor integration helpers'

  it 'retains described linked resource images while removing evidenced machine-status badges' do
    html = <<~HTML
      <html><head><title>Package resources</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset"><h1>Package resources</h1>
      <p>Compare the available package versions and their supported operating systems using the complete linked catalog.</p>
      <p><a href="https://packages.example.test/versions"><img alt="Packaging status" src="https://images.example.test/badge/packages.svg"></a></p>
      <p><a href="https://build.example.test/result"><img alt="Build status" src="https://images.example.test/build.svg"></a></p>
      <p><a href="https://build.example.test/coverage"><img alt="" src="https://images.example.test/badge/coverage.svg"></a></p>
      <p>Every described resource belongs to the published documentation; machine status controls do not replace that material.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/packages/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      [payload.fetch('html'), payload.fetch('markdown')].each do |content|
        expect(content).to include('https://packages.example.test/versions', 'Packaging status',
                                   'https://images.example.test/badge/packages.svg')
        expect(content).not_to include('https://build.example.test/result', 'https://build.example.test/coverage')
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
