# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil canonical published-entry ownership' do
  include_context 'extractor integration helpers'

  def published_entry_page
    paragraphs = (1..180).map do |index|
      "<p>Published reporting #{index} discusses source research, privacy and comments. " \
        "<a href=\"/references/#{index}\">Complete reference #{index}</a></p>"
    end.join
    <<~HTML
      <html><head><title>Complete published reporting | Source journal</title>
      <meta property="og:type" content="article"><meta property="og:title" content="Complete published reporting | Source journal">
      <meta name="author" content="Foreign global writer"><meta property="article:published_time" content="1999-01-01">
      </head><body><nav>Foreign navigation</nav><section><div class="hentry type-post status-publish">
      <div><h1><a rel="bookmark" href="/essay/report">Complete published reporting</a></h1>
      <div><a href="/essay/report">October 8, 2026</a> | in <a href="/topics/research">Research</a> | by
      <a href="/writers/source">Source Writer</a></div>
      <img src="/images/report.png" alt="Source illustration"><p>Complete physical reporting lead.</p></div>
      <div>#{paragraphs}<h2>Independent source section</h2><blockquote><p>Complete source quotation.</p></blockquote>
      <div id="comments"><article class="comment"><h3>Published reader</h3><div class="comment-body">
      <p>Actual published reply contributes additional research.</p></div></article></div>
      <p hidden>Hidden example must remain hidden.</p></div><div class="post-footer"><ul class="post-tags">
      <span>Topics:</span>#{(1..30).map { |index| "<li><a rel=\"tag\" href=\"/topics/source-#{index}\">Source topic #{index}</a></li>" }.join}
      </ul><button>Share</button></div></div></section>
      <aside>Unrelated recommended reporting</aside><footer>Foreign footer</footer></body></html>
    HTML
  end

  def published_entry_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n").sub(
      '})(window);',
      'window.hasPublishedEntry = function() { return !!canonicalPublishedEntryContext({ title: document.title }); }; })(window);'
    )
  end

  it 'retains the complete physical published entry and its owned header, lead, references and replies' do
    extract_from_url('https://publication.example.test/essay/report', published_entry_page) do |payload|
      %w[html markdown].each do |format|
        previous = -1
        (1..180).each do |index|
          value = "Published reporting #{index} discusses source research, privacy and comments."
          current = payload[format].index(value, previous + 1)
          expect(current).not_to be_nil
          expect(payload[format]).to include("Complete reference #{index}", "/references/#{index}")
          previous = current
        end
        expect(payload[format]).to include(
          'Complete physical reporting lead.', 'Source Writer', 'October 8, 2026',
          'Independent source section', 'Complete source quotation.', '/images/report.png',
          'Actual published reply contributes additional research.'
        )
        expect(payload[format]).not_to include(
          'Hidden example must remain hidden.', 'Foreign navigation', 'Unrelated recommended reporting', 'Foreign footer'
        )
        (1..30).each { |index| expect(payload[format]).to include("Source topic #{index}", "/topics/source-#{index}") }
      end
      expect(payload['title']).to eq('Complete published reporting')
      expect(payload['byline']).to eq('Source Writer')
      expect(payload['publishedTime']).to eq('October 8, 2026')
      expect(payload['excerpt']).to eq('Complete physical reporting lead.')
      expect(payload['contentType']).to eq('article')
      expect(payload['readerMode']).to be(false)
    end
  end

  it 'declines foreign, hidden, ambiguous, unpublished and conflicting entry identities' do
    valid = published_entry_page
    cases = [
      valid.sub('rel="bookmark" href="/essay/report"', 'rel="bookmark" href="/essay/foreign"'),
      valid.sub('rel="bookmark"', 'rel="tag"'),
      valid.sub('status-publish', 'status-draft'),
      valid.sub('hentry type-post', 'hentry type-page'),
      valid.sub('class="hentry type-post status-publish"', 'class="source-container"')
           .sub('<body>', '<body class="hentry type-post status-publish">'),
      valid.sub('class="hentry type-post status-publish"', 'class="source-container"')
           .sub('<html>', '<html class="hentry type-post status-publish">'),
      valid.sub('class="hentry type-post status-publish"', 'class="hentry type-post status-publish" hidden'),
      valid.sub('<h1>', '<h1 hidden>'),
      valid.sub('content="Complete published reporting | Source journal"', 'content="Foreign reporting | Source journal"'),
      valid.sub('</section>', '<div class="hentry type-post status-publish"><h1><a rel="bookmark" href="/essay/report">' \
        'Complete published reporting</a></h1><p>Conflicting owner material.</p></div></section>')
    ]
    cases.each do |html|
      with_url_page('https://publication.example.test/essay/report', html) do |page|
        page.add_script_tag(content: published_entry_source)
        expect(page.evaluate('hasPublishedEntry()')).to be(false)
      end
    end
  end
end
