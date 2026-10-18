# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Authored documentation reference labels' do
  include_context 'extractor integration helpers'

  %w[Sphinx MkDocs].each do |generator|
    it "preserves complete authored references instead of treating their labels as #{generator} controls" do
      program = "settings = 'published'\nhelp = 'complete'\nputs settings, help"
      article = <<~HTML
        <h1>Published resources</h1>
        <p>These published configuration references belong to the documentation, including their labels and destinations.</p>
        <p><a class="reference internal" href="configuration/settings.html"><span class="doc">Settings</span></a> |
        <a href="configuration/production.html">Production setup</a> |
        <a href="configuration/practices.html">Good practices</a></p>
        <h2><a href="reference/help.html">Help</a></h2>
        <p>Use the complete resource collection to configure and understand the application.</p>
        <ul><li><a href="reference/search.html">Search</a></li></ul>
        <dl><dt>Published formats</dt><dd><a href="reference/manual.pdf">PDF</a> and <a href="reference/changes.rss">RSS</a></dd></dl>
        <table><tr><th>Reference</th><th>Destination</th></tr>
        <tr><td>Published privacy explanation</td><td><a href="reference/privacy.html">Privacy policy</a></td></tr>
        <tr><td>Published usage explanation</td><td><a href="reference/terms.html">Terms of use</a></td></tr></table>
        <pre><code class="language-ruby">#{program}</code></pre>
        <p style="display:none"><a href="hidden/settings.html">Settings</a></p>
        <p hidden><a href="hidden/help.html">Help</a></p>
        <nav><ul><li><a href="controls/navigation.html">Settings</a></li></ul></nav>
        <p><a href="controls/action.html" role="button" aria-controls="settings-panel">Settings</a></p>
        <div>Settings</div>
      HTML
      root = if generator == 'Sphinx'
               "<div class=\"document\"><div class=\"section\" role=\"main\">#{article}</div></div>"
             else
               "<main class=\"md-main\"><article class=\"md-content__inner md-typeset\">#{article}</article></main>"
             end
      html = "<html><head><title>Published resources</title><meta name=\"generator\" content=\"#{generator}\"></head><body>#{root}</body></html>"
      references = {
        'configuration/settings.html' => 'Settings',
        'configuration/production.html' => 'Production setup',
        'configuration/practices.html' => 'Good practices',
        'reference/help.html' => 'Help',
        'reference/search.html' => 'Search',
        'reference/manual.pdf' => 'PDF',
        'reference/changes.rss' => 'RSS',
        'reference/privacy.html' => 'Privacy policy',
        'reference/terms.html' => 'Terms of use'
      }
      with_url_page('https://docs.publication.example.test/reference/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        [payload.fetch('html'), payload.fetch('markdown')].each do |content|
          references.each do |path, label|
            expect(content).to include("https://docs.publication.example.test/reference/#{path}", label)
          end
          expect(content).to include('These published configuration references belong to the documentation',
                                     'Use the complete resource collection', program)
          expect(content).not_to include('/hidden/settings.html', '/hidden/help.html', '/controls/navigation.html', '/controls/action.html')
        end
      end
    end
  end
end
