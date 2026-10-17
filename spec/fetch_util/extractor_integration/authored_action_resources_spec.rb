# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Authored inline action resources' do
  include_context 'extractor integration helpers'

  it 'preserves complete list, definition and cell prose references while removing actual action controls' do
    html = <<~HTML
      <html><head><title>Reference operations</title><meta name="generator" content="MkDocs 1.6"></head><body>
      <main class="md-main"><article class="md-content__inner md-typeset"><h1>Reference operations</h1>
      <p>These operations are documented resources rather than interface buttons. Preserve every word and destination.</p>
      <ul><li>Import, export, and <a href="/subscriptions">subscribe</a> to published resource lists.</li></ul>
      <dl><dt>Recovery</dt><dd>Read how to <a href="/recovery">save</a> the complete record.</dd></dl>
      <table><tr><th>Operation</th><th>Reference</th></tr><tr><td>Resources</td>
      <td>Learn to <a href="/sharing">share</a> the published collection.</td></tr></table>
      <div role="toolbar"><a href="/subscribe-control">Subscribe</a><button>Share</button></div>
      </article></main></body></html>
    HTML
    with_url_page('https://docs.publication.example.test/operations/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      [payload.fetch('html'), payload.fetch('markdown')].each do |content|
        expect(content).to include('https://docs.publication.example.test/subscriptions',
                                   'https://docs.publication.example.test/recovery',
                                   'https://docs.publication.example.test/sharing')
        expect(content).not_to include('subscribe-control')
      end
      expect(payload.fetch('markdown')).to include('Import, export, and [subscribe]', 'Read how to [save]', 'Learn to [share]')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
