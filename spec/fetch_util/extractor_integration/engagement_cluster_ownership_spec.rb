# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Leaf engagement cluster ownership' do
  include_context 'extractor integration helpers'

  def engagement_cluster(extra = '')
    <<~HTML
      <div id="reaction-faces" class="reaction-controls">
        <a href="/people/reader" aria-label="View reader profile"><picture>
          <source srcset="/reader.webp"><img src="/reader.jpg" alt="Reader avatar"></picture></a>
        <span>75 Likes</span> · <a href="/record/1/reposts">2 Reposts</a>#{extra}
      </div>
    HTML
  end

  def engagement_document(cluster, inside: false)
    paragraphs = (1..12).map do |index|
      "<p>Reporting paragraph #{index} records the primary evidence and explains its context, preserving the full published argument.</p>"
    end.join
    <<~HTML
      <html><head><title>Independent reporting</title><meta name="generator" content="Sphinx"></head>
      <body><main class="document"><article>
        <header><h1>Independent reporting</h1><div class="author">
          <a rel="author" href="/writer"><img src="/writer.jpg" alt="Writer portrait">Independent writer</a>
        </div></header><div class="article-body" itemprop="articleBody">#{paragraphs}
          <p>Source annotation<a id="ref" href="#note">1</a> has an authored <a href="/resource">resource</a>.</p>
          <div role="doc-footnote"><p id="note-text">Independent annotation<a id="note" href="#ref">↑</a></p></div>
          #{cluster if inside}</div>#{cluster unless inside}
      </article></main></body></html>
    HTML
  end

  it 'removes a wholly proved sibling control cluster without changing the original source' do
    with_url_page('https://publication.example.test/report', engagement_document(engagement_cluster)) do |page|
      result = extract(page)

      (1..12).each { |index| expect(result['markdown']).to include("Reporting paragraph #{index}") }
      expect(result['markdown']).not_to include('75 Likes', '2 Reposts', 'reader.jpg', 'reader.webp')
      expect(result['html']).to include('writer.jpg', '/resource', 'report#ref', 'Independent annotation')
      expect(page.evaluate("document.querySelector('#reaction-faces img').getAttribute('src')")).to eq('/reader.jpg')
    end
  end

  it 'preserves a cluster with an unknown authored link or paragraph' do
    ['<a href="/analysis">Independent analysis</a>', '<p>Published commentary describes the vote and its limitations.</p>'].each do |material|
      with_url_page('https://publication.example.test/report', engagement_document(engagement_cluster(material))) do |page|
        result = extract(page)

        expect(result['markdown']).to include(material.include?('/analysis') ? 'Independent analysis' : 'Published commentary')
        expect(result['html']).to include('reader.jpg')
      end
    end
  end

  it 'preserves portraits and reaction discussion within authored body material and quotes' do
    quote = '<blockquote><p>The subscription and privacy services are discussed as primary evidence.</p></blockquote>'
    with_url_page('https://publication.example.test/report', engagement_document(engagement_cluster(quote), inside: true)) do |page|
      result = extract(page)

      expect(result['markdown']).to include('subscription and privacy services', '2 Reposts')
      expect(result['html']).to include('reader.jpg')
    end
  end

  it 'preserves actual published replies and their portraits' do
    reply = '<section class="comment-thread"><div class="comment-body"><p>Published reply explains an independent observation.</p>' \
            '<a href="/people/commenter"><img src="/commenter.jpg" alt="Commenter avatar"></a></div></section>'
    with_url_page('https://publication.example.test/report', engagement_document(engagement_cluster + reply)) do |page|
      result = extract(page)

      expect(result['markdown']).to include('Published reply explains')
      expect(result['html']).to include('commenter.jpg')
      expect(result['markdown']).not_to include('75 Likes', '2 Reposts')
    end
  end

  it 'declines ambiguous body owners and source author ownership' do
    second_body = '<div class="article-body"><p>A separate authored body branch is independently material.</p></div>'
    [engagement_document(engagement_cluster + second_body),
     engagement_document(engagement_cluster.sub('reaction-controls', 'reaction-controls author-info')),
     engagement_document(engagement_cluster.sub('reaction-controls', 'reaction-controls comment-record'))].each do |html|
      with_url_page('https://publication.example.test/report', html) do |page|
        expect(extract(page)['html']).to include('reader.jpg')
      end
    end
  end
end
