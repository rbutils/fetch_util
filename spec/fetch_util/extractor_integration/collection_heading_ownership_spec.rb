require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor, 'collection heading ownership' do
  include_context 'extractor integration helpers'

  it 'retains an unlinked collection heading even when record metadata repeats its label' do
    html = <<~HTML
      <html><head><title>Daily reporting desk</title></head><body><main>
        <h1>Daily reporting desk</h1><div class='left-column'><h2>Community reporting</h2>
          #{(1..6).map do |number|
              "<article><span class='category'>Community reporting</span>" \
                "<h3><a href='/report/#{number}'>Independent local report number #{number}</a></h3>" \
                "<p>Residents explain the changing conditions and practical impact in district #{number}.</p></article>"
            end.join}
        </div>
      </main></body></html>
    HTML
    with_url_page('https://reporting.example/', html) do |page|
      markdown = extract_payload(page).fetch('markdown')
      expect(markdown.scan(/^## Community reporting$/).length).to eq(1)
      (1..6).each { |number| expect(markdown).to include("https://reporting.example/report/#{number}") }
      expect(markdown).not_to match(/^## Independent local report/)
    end
  end
end
