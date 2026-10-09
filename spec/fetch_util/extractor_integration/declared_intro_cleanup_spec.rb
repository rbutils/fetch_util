require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Declared article introductions inside sharing containers' do
  include_context 'extractor integration helpers'

  def declared_intro_page(url:, foreign: false, duplicate: false, hidden: false, action: false, declared: false, unavailable: false, competing: false)
    title = 'Independent archive measurements'
    lead = action ? 'Share this article' : 'The introductory field notes explain the independent measurements and retain monitor(x) before the complete reporting.'
    lead_html = 'The introductory <a href="/methods">field notes</a> explain the independent measurements and retain ' \
      '<code>monitor(x)</code> before the complete reporting.'
    lead_html = lead if action
    declaration = { '@type' => 'NewsArticle', 'headline' => title, 'description' => lead,
                    'mainEntityOfPage' => foreign ? 'https://another.example/report' : url }
    body = (1..4).map do |index|
      "<p>Observation #{index} preserves the complete reporting from the independent archive. " \
        'Researchers document the original measurements and describe the methods used to review each source record.</p>'
    end.join
    declaration['articleBody'] = Nokogiri::HTML.fragment(body).text if declared || unavailable
    declaration['articleBody'] += ' The remaining observations have not been materialized.' if unavailable
    <<~HTML
      <html><head><title>Archive reporting overview</title>
      <script type="application/ld+json">#{JSON.generate(declaration)}</script></head><body><main>
      <article><h1>#{title}</h1></article>
      <article><div class="sharing-shell"><section class="article-lead" #{hidden ? "hidden" : ""}>
      <p>#{lead_html}</p>#{duplicate ? "<p>#{lead_html}</p>" : ""}</section><div class="share-buttons">Copy link</div></div></article>
      <article itemprop="articleBody">#{body}</article>#{competing ? "<h1>Another independent report</h1>" : ""}</main></body></html>
    HTML
  end

  it 'retains the source-declared lead, inline resources and reporting without mutating the source' do
    url = 'https://archive.example/reports/independent-measurements'
    with_url_page(url, declared_intro_page(url: url)) do |page|
      original = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      paragraphs = Nokogiri::HTML.fragment(payload['html']).css('p').map(&:text)

      expect(paragraphs.first).to eq('The introductory field notes explain the independent measurements and retain monitor(x) before the complete reporting.')
      expect(payload['markdown']).to include('[field notes](https://archive.example/methods)', '`monitor(x)`')
      expect(payload['markdown']).not_to include('Copy link')
      expect(paragraphs.grep(/^Observation/).length).to eq(4)
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'retains all declared reporting when its introduction lives in a different article element' do
    url = 'https://archive.example/reports/declared-measurements'
    extract_from_url(url, declared_intro_page(url: url, declared: true)) do |payload|
      paragraphs = Nokogiri::HTML.fragment(payload['html']).css('p').map(&:text)
      expect(paragraphs.first).to start_with('The introductory field notes')
      expect(paragraphs.grep(/^Observation/).map { |text| text[/Observation \d+/] }).to eq((1..4).map { |index| "Observation #{index}" })
      expect(payload['markdown']).to include('[field notes](https://archive.example/methods)', '`monitor(x)`')
    end
  end

  it 'declines foreign, duplicate, hidden, control-only and unproved reporting contexts' do
    url = 'https://archive.example/reports/independent-measurements'
    [{ foreign: true }, { duplicate: true }, { hidden: true }, { action: true }, { unavailable: true }, { competing: true }].each do |variant|
      extract_from_url(url, declared_intro_page(url: url, **variant)) do |payload|
        expect(payload['markdown']).not_to include('introductory field notes', 'Share this article', 'Copy link')
        expect(Nokogiri::HTML.fragment(payload['html']).css('p').count { |node| node.text.start_with?('Observation') }).to eq(4)
      end
    end
  end
end
