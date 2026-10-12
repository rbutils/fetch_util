# frozen_string_literal: true

RSpec.describe 'FetchUtil complete homepage table peer collections' do
  include_context 'extractor integration helpers'

  around do |example|
    page = extractor_page
    previous_timeout = page.timeout
    page.timeout = 120
    example.run
  ensure
    page.timeout = previous_timeout
  end

  def table_peer_page(news: 120, updates: 80)
    reports = (1..news).map do |number|
      <<~HTML
        <a href="/reports/#{number}"><time>October #{number}, 2026</time><h2>Published report #{number}</h2>
        <p>Complete report context #{number} documents an independent materialized record.</p></a>
      HTML
    end.join
    notices = (1..updates).map do |number|
      <<~HTML
        <div><time datetime="2026-10-01">Published update #{number}</time>
        <p>Community notice #{number} explains the new published feature and its <a href="/resources/#{number}">source resource</a>.</p></div>
      HTML
    end.join
    rows = (1..8).map do |number|
      "<tr><td><a href='/events/#{number}'>Published event #{number}</a></td><td>#{number} hours remaining</td><td>#{number + 100} participants</td></tr>"
    end.join
    <<~HTML
      <html><head><title>Public community</title></head><body><nav><h2><a href="/navigation">Navigation furniture</a></h2></nav>
      <main><section>#{reports}</section><section>#{notices}</section>
      <section><h2>Published events</h2><table><tbody>#{rows}</tbody></table></section></main>
      <footer><h2><a href="/footer">Foreign footer furniture</a></h2></footer></body></html>
    HTML
  end

  def table_peer_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.tablePeerOwnership = function() {
        const tables = Array.from(document.querySelectorAll('main table'));
        return homepageTablePeerCollectionContent({title: document.title}, tables, [{}, {}, {}]);
      };
      })(window);
    JAVASCRIPT
  end

  it 'retains every physical report, community notice and table value in source order' do
    with_url_page('https://community.example.test/', table_peer_page) do |page|
      inject_standalone_extractor(page)
      page.add_script_tag(content: table_peer_source)
      payload = page.evaluate('tablePeerOwnership()')
      %w[html markdown].each do |field|
        text = payload.fetch(field)
        (1..120).each { |number| expect(text).to include("Published report #{number}", "Complete report context #{number}", "/reports/#{number}") }
        (1..80).each { |number| expect(text).to include("Community notice #{number}", "/resources/#{number}") }
        (1..8).each { |number| expect(text).to include("Published event #{number}", "#{number} hours remaining", "#{number + 100} participants") }
        expect(text.index('Published report 120')).to be < text.index('Community notice 1')
        expect(text.index('Community notice 80')).to be < text.index('Published event 1')
        expect(text).not_to include('Navigation furniture', 'Foreign footer furniture')
      end
      expect(payload['contentType']).to eq('list')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'preserves visibility and authored notices that discuss comments and membership' do
    html = table_peer_page(news: 3, updates: 2)
           .sub('</main>', '<section hidden><h2><a href="/hidden">Hidden report</a></h2><p>Hidden notice.</p></section></main>')
           .sub('Community notice 1 explains', 'Community notice 1 explains comments and membership and')
    extract_from_url('https://community.example.test/', html) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['hostAware']).to be false
      expect(payload['contentFormat']).to be_nil
      expect(payload['markdown']).to include('comments and membership', 'Published event 8')
      expect(payload['markdown']).not_to include('Hidden report', 'Hidden notice', '/hidden')
    end
  end

  it 'declines subpages, navigation-only peers, conflicting main owners and ambiguous destinations' do
    valid = table_peer_page(news: 3, updates: 2)
    cases = [
      ['https://community.example.test/records', valid],
      ['https://community.example.test/', valid.sub('<section>', '<nav>').sub('</section>', '</nav>')],
      ['https://community.example.test/', valid.sub('</main>', '</main><main><p>Different owner.</p></main>')],
      ['https://community.example.test/', valid.gsub(%r{/reports/\d+}, '/same-report')],
      ['https://community.example.test/', valid.sub('<section>', '<section hidden>')]
    ]
    cases.each do |url, html|
      with_url_page(url, html) do |page|
        page.add_script_tag(content: table_peer_source)
        expect(page.evaluate('tablePeerOwnership()')).to be_nil
      end
    end
  end
end
