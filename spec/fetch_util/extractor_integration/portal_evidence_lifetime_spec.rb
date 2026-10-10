require 'spec_helper'

RSpec.describe 'portal evidence within each native extraction' do
  include_context 'extractor integration helpers'

  def portal_html(prefix)
    sections = %w[Research Culture].map do |section|
      records = 12.times.map do |index|
        <<~HTML
          <article class="story-card">
            <h3><a href="/#{prefix}/#{section.downcase}/#{index}">#{prefix} #{section} authored report #{index}</a></h3>
            <p>#{prefix} description #{section} #{index} preserves the complete substantive interpretation of the original findings.</p>
            <figure><img src="/#{prefix}/image/#{section}/#{index}.jpg" alt="#{prefix} source image #{section} #{index}"></figure>
            <p class="byline"><a rel="author" href="/writers/#{index}">Writer #{section} #{index}</a></p>
          </article>
        HTML
      end.join
      "<section><h2>#{section}</h2>#{records}</section>"
    end.join
    "<html><head><title>#{prefix} news index</title></head><body><main><h1>#{prefix} news index</h1>#{sections}</main></body></html>"
  end

  it 'retains all owned records and reflects a changed document on the next extraction' do
    with_url_page('https://updates.example.test/', portal_html('Initial')) do |page|
      extractor = FetchUtil::Extractor.new
      first = extractor.extract(page)
      expect(first['contentType']).to eq('list')
      page.evaluate_func(<<~JAVASCRIPT, portal_html('Updated'))
        html => {
          const parsed = new DOMParser().parseFromString(html, 'text/html');
          document.replaceChild(document.importNode(parsed.documentElement, true), document.documentElement);
          return true;
        }
      JAVASCRIPT
      second = extractor.extract(page)
      expect(second['contentType']).to eq('list')
      expect(second['markdown']).not_to include('Initial')
      %w[Research Culture].each do |section|
        12.times do |index|
          expect(first['markdown']).to include("Initial #{section} authored report #{index}", "Initial description #{section} #{index}")
          expect(second['markdown']).to include("Updated #{section} authored report #{index}", "Updated description #{section} #{index}")
          expect(second['html']).to include("/Updated/image/#{section}/#{index}.jpg", "Writer #{section} #{index}")
        end
      end
    end
  end
end
