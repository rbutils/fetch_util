# frozen_string_literal: true

RSpec.describe FetchUtil::Extractor, 'named overlay card links' do
  include_context 'extractor integration helpers'

  def overlay_cards
    (1..6).map do |number|
      title = "Independent regional investigation #{number}"
      "<li><div><a class='cover' href='/lead/#{number}' aria-label='#{title}'></a>" \
        "<img src='/image/#{number}.jpg'><h3><span>Region</span><span>#{title}</span></h3>" \
        "<p>Local evidence and reporting for investigation #{number}.</p>" \
        "<ul><li><a href='/followup/#{number}'><h3>Separate follow-up investigation #{number}</h3></a></li></ul>" \
        '</div></li>'
    end.join
  end

  it 'keeps the visible lead destination alongside its independently linked follow-up' do
    html = "<html><body><main><h1>Regional bulletin</h1><ul>#{overlay_cards}</ul></main></body></html>"
    with_url_page('https://bulletin.example/', html) do |page|
      original = page.evaluate('document.body.innerHTML')
      markdown = described_class.new.extract(page).fetch('markdown')
      (1..6).each do |number|
        expect(markdown).to include("[Independent regional investigation #{number}](https://bulletin.example/lead/#{number})")
        expect(markdown).to include("https://bulletin.example/followup/#{number}")
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(original)
    end
  end

  it 'does not promote an unmatched, hidden or unsafe overlay over its visible record' do
    html = '<html><body><main><h1>Regional bulletin</h1><ul>' \
           "#{overlay_cards}" \
           '<li><a href="/wrong" aria-label="An unrelated destination label"></a><img src="/image.jpg">' \
           '<h3><a href="/actual">Actual independently linked investigation</a></h3></li>' \
           '<li><a hidden href="/hidden" aria-label="Hidden investigation label"></a>' \
           '<a href="javascript:void(0)" aria-label="Hidden investigation label"></a>' \
           '<h3>Hidden investigation label</h3><img src="/other.jpg"></li></ul></main></body></html>'
    with_url_page('https://bulletin.example/', html) do |page|
      markdown = described_class.new.extract(page).fetch('markdown')
      expect(markdown).to include('https://bulletin.example/actual')
      expect(markdown).not_to include(
        '[Actual independently linked investigation](https://bulletin.example/wrong)', '/hidden)', 'javascript:'
      )
    end
  end
end
