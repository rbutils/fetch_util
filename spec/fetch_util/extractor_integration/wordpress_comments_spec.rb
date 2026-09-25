# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil WordPress article comments' do
  include_context 'extractor integration helpers'

  def wordpress_comment(id, children: '')
    <<~HTML
      <li id="comment-#{id}" class="comment"><footer><a href="/readers/#{id}">Reader #{id}</a>
        <time datetime="2026-09-24T12:00:00Z">24 September, noon</time></footer>
        <div class="comment-body"><p>Reader observation #{id} about the river restoration.</p></div>
        #{children}
      </li>
    HTML
  end

  def wordpress_discussion_page(thread)
    <<~HTML
      <html><head><title>Restoring a river</title><meta name="generator" content="WordPress"></head><body>
        <main><article id="post-42"><h1 class="entry-title">Restoring a river</h1><div class="entry-content">
          <p>The restoration team returned to the river to measure the effect of removing the concrete barriers.</p>
          <p>Their observations showed that native plants had returned, while water quality and wildlife habitats continued to improve.</p>
          <p>The team will publish its final measurements after the next season of fieldwork.</p>
        </div></article></main>#{thread}
      </body></html>
    HTML
  end

  it 'retains every post-owned comment and nested reply with authors, dates, links, and source order' do
    replies = (2..26).map { |id| wordpress_comment(id) }.join
    thread = "<ol class='comment-list' data-post-id='42'>#{wordpress_comment(1, children: "<ol class='children'>#{replies}</ol>")}</ol>"
    html = wordpress_discussion_page(thread)

    with_url_page('https://example-blog.test/restoring-a-river/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page)
      positions = (1..26).map do |id|
        expect(payload['markdown'].scan("Reader observation #{id} about").length).to eq(1)
        expect(payload['markdown']).to include("https://example-blog.test/readers/#{id}")
        payload['markdown'].index("Reader observation #{id} about")
      end
      expect(positions).to eq(positions.sort)
      expect(payload['html']).to include('datetime="2026-09-24T12:00:00Z"', 'class="children"')
      expect(payload['markdown'].scan('24 September, noon').length).to eq(26)
      expect(payload['excerpt']).to start_with('The restoration team returned')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'accepts an external WordPress discussion owned by its comment form post ID' do
    thread = <<~HTML
      <section id="comments"><ol class="comment-list">#{wordpress_comment(7)}</ol>
        <form><input type="hidden" name="comment_post_ID" value="42"></form>
      </section>
    HTML
    extract_from_url('https://example-blog.test/restoring-a-river/', wordpress_discussion_page(thread)) do |payload|
      expect(payload['markdown']).to include('Reader observation 7 about', 'Reader 7')
      expect(payload['html']).not_to include('<form', '<input')
    end
  end

  it 'retains a post-owned image-only comment' do
    thread = <<~HTML
      <div class="comments-list" data-post-id="42"><div class="comment-item">
        <strong>River photographer</strong><div class="comment-body"><img src="/survey.jpg" alt="River survey"></div>
      </div></div>
    HTML
    extract_from_url('https://example-blog.test/restoring-a-river/', wordpress_discussion_page(thread)) do |payload|
      expect(payload['markdown']).to include('River photographer', '![River survey](https://example-blog.test/survey.jpg)')
    end
  end

  it 'rejects foreign, conflicting, hidden, sidebar, unowned, and empty discussions' do
    list = "<ol class='comment-list' data-post-id='42'>#{wordpress_comment(99)}</ol>"
    variants = [
      list.sub("data-post-id='42'", "data-post-id='43'"), list.sub("data-post-id='42'", ''),
      "<section id='comments'>#{list}<form><input name='comment_post_ID' value='43'></form></section>",
      "<aside>#{list}</aside>", "<article id='post-43'>#{list}</article>",
      "<div hidden>#{list}</div>", "<div style='visibility:hidden'>#{list}</div>",
      "<ol class='comment-list' data-post-id='42'><button>Write a comment</button></ol>"
    ]
    variants.each do |thread|
      extract_from_url('https://example-blog.test/restoring-a-river/', wordpress_discussion_page(thread)) do |payload|
        expect(payload['markdown']).not_to include('Reader observation', 'Write a comment')
      end
    end
  end
end
