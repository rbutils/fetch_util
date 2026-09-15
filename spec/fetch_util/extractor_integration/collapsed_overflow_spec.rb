require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor, 'collapsed overflow content' do
  include_context 'extractor integration helpers'

  def collapsed_page(style)
    <<~HTML
      <html><head><title>Community resource guide</title></head><body><main>
        <h1>Community resource guide</h1>
        <p>This guide describes the public resources available to residents and the process for choosing an appropriate service.</p>
        <p>Each service has its own opening hours and contact details. Readers can use these details to prepare for their visit.</p>
        <div class='panel' style='#{style}'><h2>Additional community directory</h2>
          #{(1..8).map { |n| "<p><a href='/directory/#{n}'>Community directory entry number #{n}</a></p>" }.join}
        </div>
        <p><a href='/public-guide'>Read the complete public guide</a> for the current service information and visiting requirements.</p>
      </main></body></html>
    HTML
  end

  it 'excludes descendants of zero-sized explicitly clipping panels' do
    ['height: 0; overflow: hidden', 'width: 0; overflow: clip',
     'display: flex; height: 0; overflow: hidden', 'display: grid; height: 0; overflow: hidden'].each do |style|
      [true, false].each do |reader_mode|
        with_url_page('https://community.example/guide', collapsed_page(style)) do |page|
          before = page.evaluate('document.body.outerHTML')
          markdown = extract_payload(page, reader_mode: reader_mode).fetch('markdown')
          expect(markdown).to include('public resources available to residents', 'https://community.example/public-guide')
          expect(markdown).not_to include('Additional community directory', 'Community directory entry', '/directory/')
          expect(page.evaluate('document.body.outerHTML')).to eq(before)
        end
      end
    end
  end

  it 'preserves visible overflow and scroll-reachable entries' do
    ['height: 0; overflow: visible', 'height: 40px; overflow: auto', 'height: 40px; overflow: scroll'].each do |style|
      with_url_page('https://community.example/guide', collapsed_page(style)) do |page|
        markdown = extract_payload(page).fetch('markdown')
        (1..8).each { |n| expect(markdown).to include("https://community.example/directory/#{n}") }
      end
    end
  end

  it 'preserves an explicitly expanded overflow clip margin' do
    with_url_page('https://community.example/guide', collapsed_page('height: 0; overflow: clip; overflow-clip-margin: 2000px')) do |page|
      markdown = extract_payload(page).fetch('markdown')
      (1..8).each { |n| expect(markdown).to include("https://community.example/directory/#{n}") }
    end
  end

  it 'does not assume a zero-sized box clips independently positioned descendants' do
    %w[absolute fixed].each do |position|
      positioned = "<p style='position: #{position}; top: 200px; left: 20px'>" \
                   "<a href='/emergency'>Emergency contact outside the clipping box</a></p>"
      html = collapsed_page('height: 0; overflow: hidden').sub('<h2>Additional community directory</h2>', positioned)
      with_url_page('https://community.example/guide', html) do |page|
        markdown = extract_payload(page).fetch('markdown')
        expect(markdown).to include('https://community.example/emergency')
      end
    end
  end

  it 'checks positioned descendants inside open components before discarding a clipping box' do
    with_url_page('https://community.example/guide', collapsed_page('height: 0; overflow: hidden')) do |page|
      page.evaluate(<<~JS)
        (() => {
          const host = document.createElement('div');
          host.attachShadow({mode: 'open'}).innerHTML =
            '<p style="position: fixed; top: 200px; left: 20px"><a href="/component-help">Visible component contact</a></p>';
          document.querySelector('.panel').appendChild(host);
        })()
      JS
      expect(extract_payload(page).fetch('markdown')).to include('https://community.example/component-help')
    end
  end
end
