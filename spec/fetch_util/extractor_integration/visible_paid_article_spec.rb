# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'Source-owned visible reporting with paid access metadata' do
  include_context 'extractor integration helpers'

  def reporting_paragraphs
    (1..6).map do |number|
      "<p>Record #{number} documents the original measurements collected by the borough's independent archive team. " \
        'The researchers describe their methods, publish the complete figures and explain the limits of each observation. ' \
        'Residents can compare the reported results with the original records and follow the documented review process.</p>'
    end.join
  end

  def declared_reporting_page(body: reporting_paragraphs, before: '', after: '', extra: '', headline: 'Public archive records')
    <<~HTML
      <html><head><title>Public archive records</title>
      <meta property="og:type" content="article">
      <script type="application/ld+json">#{JSON.generate("@type" => "NewsArticle", "headline" => headline, "isAccessibleForFree" => false)}</script>
      </head><body><main><article><header><h1>Public archive records</h1>
      <time datetime="2026-10-08T08:00:00Z">8 October 2026</time></header>
      #{before}<div itemprop="articleBody">#{body}</div>#{after}</article>#{extra}</main></body></html>
    HTML
  end

  it 'retains all reporting and original access evidence without asserting that the article is free' do
    html = declared_reporting_page(before: '<div class="paywall">Suscríbete para acceder a todas las ventajas de PREMIUM.</div>')
    with_url_page('https://archive.example/reports/public-archive-records', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      declaration = page.evaluate('document.querySelector("script[type=\"application/ld+json\"]").textContent')
      payload = FetchUtil::Extractor.new.extract(page)
      expected = Nokogiri::HTML.fragment(reporting_paragraphs).css('p').map(&:text)
      actual = Nokogiri::HTML.fragment(payload['html']).css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }

      expect(actual & expected).to eq(expected)
      expect(payload['warnings']).not_to include('paywall_partial_content')
      expect(payload['paywallState']).to eq('detected')
      expect(payload['publishedTime']).to eq('2026-10-08T08:00:00Z')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(page.evaluate('document.querySelector("script[type=\"application/ld+json\"]").textContent')).to eq(declaration)
    end
  end

  it 'keeps an access warning for a visible continuation boundary after the reporting' do
    html = declared_reporting_page(after: '<div class="paywall">Subscribe to continue reading the complete report.</div>')
    extract_from_url('https://archive.example/reports/public-archive-records', html) do |payload|
      expect(payload['warnings']).to include('subscription_interstitial')
      expect(payload['paywallState']).to eq('full_block')
    end
  end

  it 'does not use hidden paragraphs or quoted reporting to prove the visible article complete' do
    ["<div hidden>#{reporting_paragraphs}</div>", "<blockquote>#{reporting_paragraphs}</blockquote>"].each do |unowned|
      html = declared_reporting_page(body: "<p>This is the visible introduction to the archive report, followed by a restricted continuation.</p>#{unowned}")
      extract_from_url('https://archive.example/reports/public-archive-records', html) do |payload|
        expect(payload['warnings']).to include('paywall_partial_content')
      end
    end
  end

  it 'declines conflicting declarations and competing source headlines' do
    [
      declared_reporting_page(headline: 'Another archive report'),
      declared_reporting_page(extra: '<article><h1>Another independently authored report</h1><p>Separate reporting.</p></article>')
    ].each do |html|
      extract_from_url('https://archive.example/reports/public-archive-records', html) do |payload|
        expect(payload['warnings']).to include('paywall_partial_content')
      end
    end
  end

  it 'removes an empty comment jump while preserving the published discussion and its authored reference' do
    discussion = <<~HTML
      <section class="discussion-comments"><a href="#comments">Comentarios</a></section>
      <section id="comments"><p>A reader supplies the missing archival context and cites
      <a href="#responses">Comentarios</a> as the original discussion of those measurements.</p></section>
    HTML
    html = declared_reporting_page(after: discussion)
    extract_from_url('https://archive.example/reports/public-archive-records', html) do |payload|
      expect(payload['markdown']).not_to include('](https://archive.example/reports/public-archive-records#comments)')
      expect(payload['markdown']).to include(
        'A reader supplies the missing archival context', 'the original discussion of those measurements.',
        '[Comentarios](https://archive.example/reports/public-archive-records#responses)'
      )
    end
  end

  it 'keeps a numeric discussion headline while excluding subordinate discussion actions from story destinations' do
    cards = ['20 comentarios', 'Archive publishes the original annual measurements',
             'Borough releases complete reporting methodology', 'Independent review explains the archive findings'].map.with_index do |title, index|
      <<~HTML
        <article><h2><a href="/reports/#{index}">#{title}</a></h2>
        <a href="/discussion/#{index}">#{index + 3} comentarios</a>
        <p>The complete source report and its supporting archive records are available for independent review.</p></article>
      HTML
    end.join
    html = "<html><head><title>Archive reports</title></head><body><main>#{cards}</main></body></html>"
    extract_from_url('https://archive.example/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('[20 comentarios](https://archive.example/reports/0)')
      expect(payload['markdown']).not_to include('](https://archive.example/discussion/')
      expect(payload['warnings']).not_to include('multi_topic_page')
    end
  end
end
