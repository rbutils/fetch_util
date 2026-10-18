# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Authored numeric values' do
  include_context 'extractor integration helpers'

  %w[Sphinx MkDocs].each do |generator|
    it "retains adjacent measured values and numeric-only prose in #{generator}" do
      program = "observations = [75, 1]\nputs observations"
      article = <<~HTML
        <h1>Published measurements</h1>
        <p>These complete observations describe recorded progress and remain part of the published account.</p>
        <h2>Daily progress</h2>
        <div id="recorded-measurements">
          <div>Ride</div>
          <div>75</div>
          <div>1</div>
          <div>days needed for the next checkpoint</div>
        </div>
        <h2>Recorded pair</h2>
        <p>12 34</p>
        <p>The complete pair belongs to the observations, followed by the reproducible program and its reference.</p>
        <pre><code class="language-ruby">#{program}</code></pre>
        <p><a href="methods/measurement.html">Measurement method</a></p>
        <nav aria-label="Image pagination"><a href="gallery/previous.html">Previous image</a><a href="gallery/next.html">Next image</a></nav>
        <div hidden>908 765</div>
      HTML
      owner = if generator == 'Sphinx'
                "<div class=\"document\"><div class=\"section\" role=\"main\">#{article}</div></div>"
              else
                "<main class=\"md-main\"><article class=\"md-content__inner md-typeset\">#{article}</article></main>"
              end
      html = "<html><head><title>Published measurements</title><meta name=\"generator\" content=\"#{generator}\"></head><body>#{owner}</body></html>"
      with_url_page('https://docs.measurements.example.test/records/', html) do |page|
        before = page.evaluate('document.body.innerHTML')
        payload = extract(page)
        expect(page.evaluate('document.body.innerHTML')).to eq(before)
        expect(payload.fetch('markdown')).to match(/Ride\s+75\s+1\s+days needed for the next checkpoint/)
        expect(payload.fetch('markdown')).to match(/(?:^|\n)12 34(?:\n|$)/)
        [payload.fetch('html'), payload.fetch('markdown')].each do |content|
          expect(content).to include('These complete observations', 'The complete pair belongs', program,
                                     'https://docs.measurements.example.test/records/methods/measurement.html')
          expect(content).not_to include('908 765', '/gallery/previous.html', '/gallery/next.html')
        end
      end
    end
  end
end
