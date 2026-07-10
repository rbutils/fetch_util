# frozen_string_literal: true

RSpec.describe 'FetchUtil generic visible collections' do
  include_context 'extractor integration helpers'

  def portal_cards(section, count)
    Array.new(count) do |index|
      number = index + 1
      duplicate = number == 1
      tracking_query = section == 1 ? "utm_source=first" : "fbclid=second"
      url = if duplicate
              "/stories/shared?#{tracking_query}"
            else
              "/stories/#{section}-#{number}"
            end
      title = duplicate ? 'Shared story' : "Section #{section} story #{number}"
      "<article class=\"card\"><h3><a href=\"#{url}\">#{title}</a></h3><p>Editorial detail #{section}-#{number}.</p></article>"
    end.join
  end

  it 'keeps every accepted section card in DOM order with global canonical dedupe' do
    html = <<~HTML
      <html><head><title>Daily portal</title></head><body><main>
        <section><h2>First section</h2>#{portal_cards(1, 5)}</section>
        <section><h2>Second section</h2>#{portal_cards(2, 5)}</section>
      </main></body></html>
    HTML

    with_url_page('https://portal.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      markdown = payload['markdown']
      urls = markdown.scan(%r{\]\((https://portal\.example/[^)]+)\)}).flatten

      expect(payload['contentType']).to eq('list')
      expect(urls.length).to eq(9)
      expect(urls).to eq(
        [
          'https://portal.example/stories/shared',
          'https://portal.example/stories/1-2',
          'https://portal.example/stories/1-3',
          'https://portal.example/stories/1-4',
          'https://portal.example/stories/1-5',
          'https://portal.example/stories/2-2',
          'https://portal.example/stories/2-3',
          'https://portal.example/stories/2-4',
          'https://portal.example/stories/2-5'
        ]
      )
      expect(markdown).to include('## First section')
      expect(markdown).to include('## Second section')
    end
  end

  it 'keeps flat portal headings and items beyond the old presentation limits' do
    headings = Array.new(13) do |index|
      number = index + 1
      "<article><h2>Portal heading #{number}</h2><a href=\"/items/#{number}\">Portal item #{number} with useful detail</a></article>"
    end.join
    html = "<html><head><title>Portal</title></head><body><main><h1>Portal home</h1>#{headings}</main></body></html>"

    with_url_page('https://flat.example/', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan(/^-/).length).to eq(26)
      expect(payload['markdown']).to include('- Portal heading 13')
      expect(payload['markdown']).to include('Portal item 13 with useful detail')
    end
  end

  it 'materializes more than 80 generic list entries without reordering them' do
    rows = Array.new(81) do |index|
      number = index + 1
      "<article><h2><a href=\"/entries/#{number}\">Generic entry #{number} with enough title text</a></h2></article>"
    end.join
    html = "<html><head><title>Entries</title></head><body><main>#{rows}</main></body></html>"

    with_url_page('https://list.example/entries', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].scan(/^-/).length).to eq(81)
      expect(payload['markdown']).to include('Generic entry 1 with enough title text')
      expect(payload['markdown']).to include('Generic entry 81 with enough title text')
    end
  end

  it 'arbitrates between plausible containers using relevant links after position 80' do
    container = lambda do |name, section_path|
      links = Array.new(80) do |index|
        number = index + 1
        "<article><a href=\"/#{name}/neutral-#{number}\">#{name} neutral story #{number} with useful detail</a></article>"
      end.join
      decisive_title = name == 'technology' ? 'technology story after the visible boundary' : 'Privacy policy'
      links << "<article><a href=\"/#{section_path}/decisive\">#{decisive_title}</a></article>"
      "<section class=\"stories\" data-container=\"#{name}\">#{links}</section>"
    end
    html = <<~HTML
      <html><head><title>Technology news</title></head><body>
        <main>#{container.call("archive", "privacy")}#{container.call("technology", "technology")}</main>
      </body></html>
    HTML

    with_url_page('https://portal.example/category/technology', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown']).to include('technology story after the visible boundary')
      expect(payload['markdown']).to include('https://portal.example/technology/decisive')
      expect(payload['markdown']).not_to include('https://portal.example/privacy/decisive')
    end
  end

  it 'keeps all generic search results in DOM order' do
    results = Array.new(13) do |index|
      number = index + 1
      "<div class=\"g\"><a href=\"https://results.example/item/#{number}\"><h3>Search result #{number} with useful title</h3></a><p>Result detail.</p></div>"
    end.join
    html = "<html><head><title>results - Google Search</title></head><body><main>#{results}</main></body></html>"

    with_url_page('https://www.google.com/search?q=results', html) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('search')
      expect(payload['markdown'].scan(/^-/).length).to eq(13)
      expect(payload['markdown']).to include('Search result 13 with useful title')
    end
  end

  it 'keeps all Pinterest and eBay search results' do
    pinterest_links = Array.new(13) do |index|
      number = index + 1
      "<a href=\"/pin/#{number}/\" aria-label=\"Pinterest result #{number} with useful title\"></a>"
    end.join
    ebay_links = Array.new(13) do |index|
      number = index + 1
      "<li class=\"s-item\"><a class=\"s-item__link\" href=\"/itm/#{number}\">eBay result #{number} with useful title</a></li>"
    end.join

    with_url_page('https://www.pinterest.com/search/pins/?q=results', "<main>#{pinterest_links}</main>") do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload['markdown'].scan(/^-/).length).to eq(13)
      expect(payload['markdown']).to include('Pinterest result 13 with useful title')
    end

    with_url_page('https://www.ebay.com/sch/i.html?_nkw=results', "<main><ul>#{ebay_links}</ul></main>") do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)
      expect(payload['markdown'].scan(/^-/).length).to eq(13)
      expect(payload['markdown']).to include('eBay result 13 with useful title')
    end
  end
end
