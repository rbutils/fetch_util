# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil exact-permalink post ownership' do
  include_context 'extractor integration helpers'

  def permalink_post_page(first_list:, outside: '')
    <<~HTML
      <html>
        <head>
          <title>Research team publishes the complete field report | Archive</title>
          <meta property="article:published_time" content="2014-10-21T16:06:00Z">
        </head>
        <body>
          <main>
            <div class="entry-collection">
              #{first_list}
              <ul class="older-posts">
                <li><h3>Unrelated weather bulletin</h3><p>An older independent report discusses a different public event.</p></li>
              </ul>
              #{outside}
            </div>
          </main>
        </body>
      </html>
    HTML
  end

  def permalink_post
    body = (1..12).map do |index|
      "<p>Visible report paragraph #{index}: each part supplies separate verified context about the research team's complete public field report.</p>"
    end.join
    <<~HTML
      <li class="current-entry">
        <h3><a href="/posts/2026/07/06/field-report/">Research team publishes the complete field report</a></h3>
        #{body}
      </li>
    HTML
  end

  def permalink_evidence_source
    @permalink_evidence_source ||= begin
      project = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(project, 'websieve/manifest.txt'), chomp: true)
                   .reject { |entry| entry.empty? || entry.start_with?('#') }
                   .map { |entry| File.read(File.join(project, 'websieve', entry)) }.join("\n")
      source.sub('})(window);', <<~JS.chomp)
        global.__focalPermalinkEvidence = function() {
          return focalPermalinkArticleContent(collectMetadata());
        };
        })(window);
      JS
    end
  end

  let(:url) { 'https://reports.example/posts/2026/07/06/field-report/' }

  it 'keeps every visible paragraph under a uniquely owned current permalink without neighboring posts' do
    html = permalink_post_page(first_list: "<ul class='current-post'>#{permalink_post}</ul>")

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload).to include(
        'title' => 'Research team publishes the complete field report',
        'contentType' => 'article', 'readerMode' => false, 'hostAware' => false,
        'publishedTime' => '2026-07-06'
      )
      expect(payload.fetch('excerpt')).to start_with('Visible report paragraph 1:')
      expect(payload.fetch('markdown').scan('Research team publishes the complete field report').size).to eq(1)
      positions = (1..12).map do |index|
        phrase = "Visible report paragraph #{index}:"
        expect(payload.fetch('markdown').scan(phrase).size).to eq(1)
        expect(payload.fetch('html').scan(phrase).size).to eq(1)
        payload.fetch('markdown').index(phrase)
      end
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('markdown')).not_to include('Unrelated weather bulletin', 'An older independent report')
      expect(payload.fetch('warnings')).not_to include('multi_topic_page')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not narrow a shared list where the current link is only one of several records' do
    first_list = "<ul class='current-post'>#{permalink_post}" \
                 "<li><h3><a href='/posts/2026/07/06/second-report/'>Another complete report</a></h3>" \
                 "<p>Another independent source report must survive alongside the first linked entry.</p></li></ul>"
    html = permalink_post_page(first_list: first_list)

    with_url_page(url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: permalink_evidence_source)

      expect(page.evaluate('window.__focalPermalinkEvidence()')).to be_nil
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not discard a separate published comment outside the post owner' do
    outside = "<article itemprop='comment'><p>A published correction adds material public context to this report.</p></article>"
    html = permalink_post_page(first_list: "<ul class='current-post'>#{permalink_post}</ul>", outside: outside)

    with_url_page(url, html) do |page|
      page.add_script_tag(content: permalink_evidence_source)
      expect(page.evaluate('window.__focalPermalinkEvidence()')).to be_nil
      payload = extract_payload(page)

      expect(payload.fetch('markdown')).to include('A published correction adds material public context')
    end
  end
end
