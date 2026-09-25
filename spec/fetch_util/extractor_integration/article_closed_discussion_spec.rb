# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil closed-discussion notices' do
  include_context 'extractor integration helpers'

  def closed_discussion_article(extra)
    <<~HTML
      <html><head><title>Restoring a river</title><meta name="generator" content="WordPress"></head><body>
        <article><h1 class="entry-title">Restoring a river</h1><div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
          <p>Their observations showed that native plants had returned, while water quality and wildlife habitats continued to improve.</p>
          <p>The team will publish its final measurements after the next season of fieldwork.</p>#{extra}
        </div></article>
      </body></html>
    HTML
  end

  it 'removes complete inert discussion notices without changing article prose or the source DOM' do
    notice = 'O wee, die gesang is uit! Die kommentaar op hierdie berig is gesluit. Kom kuier gerus lekker verder saam op ŉ ander artikel.'
    extras = [
      "<p>#{notice}</p>", '<p class="no-comments">Comments are closed.</p>',
      '<p role="status">Commenting is closed.</p>',
      '<p class="comments-closed">Die kommentaar op hierdie artikel is gesluit.</p>'
    ]
    extras.each do |extra|
      with_url_page('https://example-blog.test/river/', closed_discussion_article(extra)) do |page|
        before = page.evaluate('document.body.outerHTML')
        payload = extract_payload(page)
        expect(payload['html']).not_to include('gesluit', 'Comments are closed', 'Commenting is closed')
        expect(payload['markdown']).not_to include('gesluit', 'Comments are closed', 'Commenting is closed')
        expect(payload['markdown']).to include('native plants had returned', 'final measurements')
        expect(payload['excerpt']).to start_with('The restoration team returned')
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end

  it 'preserves quotes, code, reader comments, editorial text, destinations, and media' do
    variants = [
      ['<p>Comments are closed.</p>', 'Comments are closed.'],
      ['<p class="no-comments">The editor explained why comments are closed.</p>', 'The editor explained why'],
      ['<p class="no-comments">Comments are closed. Readers challenged this decision.</p>', 'Readers challenged this decision.'],
      ['<blockquote><p class="no-comments">Comments are closed.</p></blockquote>', 'Comments are closed.'],
      ['<pre><code>Comments are closed.</code></pre>', 'Comments are closed.'],
      ['<p class="no-comments">Comments are <a href="/policy">closed</a>.</p>', 'https://example-blog.test/policy'],
      ['<p class="no-comments">Comments are closed.<img src="/notice.png" alt="Published notice"></p>', 'https://example-blog.test/notice.png'],
      ['<div data-fetchutil-social-comment="true"><div class="comment_content"><p class="no-comments">Comments are closed.</p></div></div>', 'Comments are closed.'],
      ['<p>“O wee, die gesang is uit! Die kommentaar op hierdie berig is gesluit.”</p>', 'Die kommentaar op hierdie berig is gesluit.']
    ]
    variants.each do |extra, expected|
      extract_from_url('https://example-blog.test/river/', closed_discussion_article(extra)) do |payload|
        expect(payload['markdown']).to include(expected)
      end
    end
  end
end
