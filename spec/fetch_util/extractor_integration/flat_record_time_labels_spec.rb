require 'spec_helper'

RSpec.describe 'FetchUtil flat-record time declarations' do
  include_context 'extractor integration helpers'
  include_context 'heading record prose'

  def flat_time_page(declarations)
    articles = (1..4).map do |number|
      <<~HTML
        <article><h2><a href="/main/#{number}">Independent main reporting number #{number}</a></h2>
          <p>Complete independent reporting for the main publication #{number}.</p></article>
      HTML
    end.join
    peers = (1..8).map do |number|
      detail = declarations[number - 1]
      contents =
        if detail
          value, label = detail
          <<~HTML
            <h3>Independent regional report number #{number}</h3>
            <p>Complete regional context belonging only to report #{number}.</p>
            <span class="author">Regional reporter #{number}</span>
            <time datetime="#{value}">#{label}</time>
          HTML
        else
          "Independent regional report number #{number}"
        end
      "<a href=\"/peer/#{number}\">#{contents}</a>"
    end.join
    <<~HTML
      <html><head><title>Schedule bulletin</title></head><body><main>
        <h1>Schedule bulletin</h1>#{articles}
        <section><h2>Regional schedule</h2><p>These reports retain their independently declared schedule information.</p>
          <div class="links-box">#{peers}<div class="layout-spacer"></div></div></section>
      </main></body></html>
    HTML
  end

  def with_flat_time_result(declarations)
    with_url_page('https://schedule.publication.example.test/', flat_time_page(declarations)) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: true).extract(page)
      expect(payload['title']).to eq('Schedule bulletin')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan(/^## Regional schedule$/).length).to eq(1)
      expect(payload['markdown'].scan('These reports retain their independently declared schedule information.').length).to eq(1)
      (1..4).each do |number|
        expect(payload['markdown']).to include("[Independent main reporting number #{number}](https://schedule.publication.example.test/main/#{number})")
      end
      (1..8).each do |number|
        expect(payload['markdown']).to include("https://schedule.publication.example.test/peer/#{number}")
      end
      yield payload['markdown']
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  def flat_peer_record(markdown, number)
    heading_record_prose(markdown, destination: "https://schedule.publication.example.test/peer/#{number}")
  end

  it 'retains each visible label beside its own literal declaration without borrowing neighboring metadata' do
    declarations = [['2026-09-14', 'September 14'], ['2026-09-13', 'September 13']]
    with_flat_time_result(declarations) do |markdown|
      declarations.each_with_index do |(value, label), index|
        record = flat_peer_record(markdown, index + 1).text
        expect(record).to include("#{label} (#{value})", "Regional reporter #{index + 1}")
        expect(record.scan(value).length).to eq(1)
        expect(record.scan(label).length).to eq(1)
        expect(record).not_to include(*declarations.fetch(1 - index))
        expect(markdown).to include("Complete regional context belonging only to report #{index + 1}.")
      end
    end
  end

  it 'preserves independent occurrences with identical declared values' do
    declarations = [['2026-09-14T09:00:00+02:00', 'Morning dispatch'], ['2026-09-14T09:00:00+02:00', 'Later editorial label']]
    with_flat_time_result(declarations) do |markdown|
      expect(markdown.scan('2026-09-14T09:00:00+02:00').length).to eq(2)
      declarations.each_with_index do |(value, label), index|
        expect(flat_peer_record(markdown, index + 1).text).to include("#{label} (#{value})")
      end
    end
  end

  it 'retains authored inline emphasis and code within the visible labels' do
    declarations = [['2026-09-15', '<strong>September 15</strong>'], ['2026-09-16', '<em>Later release</em> <code>revision_2</code>']]
    with_flat_time_result(declarations) do |markdown|
      first = flat_peer_record(markdown, 1)
      second = flat_peer_record(markdown, 2)
      expect(first.text).to include('September 15 (2026-09-15)')
      expect(first.css('strong').map(&:text)).to eq(['September 15'])
      expect(second.text).to include('Later release revision_2 (2026-09-16)')
      expect(second.css('em').map(&:text)).to eq(['Later release'])
      expect(second.css('code').map(&:text)).to eq(['revision_2'])
    end
  end

  it 'keeps an already represented declaration once and retains an empty-label declaration' do
    declarations = [['2026-09-17', '<span>Updated 2026-09-17</span>'], ['2026-09-18', '']]
    with_flat_time_result(declarations) do |markdown|
      expect(flat_peer_record(markdown, 1).text).to include('Updated 2026-09-17')
      expect(flat_peer_record(markdown, 1).text.scan('2026-09-17').length).to eq(1)
      expect(flat_peer_record(markdown, 2).text.scan('2026-09-18').length).to eq(1)
    end
  end

  it 'retains only the visible portions of declared time labels' do
    declarations = [
      ['2026-09-19', '<span hidden>Hidden schedule detail</span><strong>September 19</strong>'],
      ['2026-09-20', '<span style="display:none">Styled hidden detail</span><em>September 20</em>']
    ]
    with_flat_time_result(declarations) do |markdown|
      first = flat_peer_record(markdown, 1)
      second = flat_peer_record(markdown, 2)
      expect(first.text).to include('September 19 (2026-09-19)')
      expect(first.css('strong').map(&:text)).to eq(['September 19'])
      expect(second.text).to include('September 20 (2026-09-20)')
      expect(second.css('em').map(&:text)).to eq(['September 20'])
      expect(markdown).not_to include('Hidden schedule detail', 'Styled hidden detail')
    end
  end
end
