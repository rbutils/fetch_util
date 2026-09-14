require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor, 'horizontal content clipping' do
  include_context 'extractor integration helpers'

  def clipping_page(overflow: 'hidden', extra: '')
    <<~HTML
      <!doctype html><html><head><title>Daily regional headlines</title><style>
        .carousel { width: 360px; overflow-x: #{overflow}; }
        .track { display: flex; width: 900px; }
        .slide { flex: 0 0 300px; }
      </style></head><body><main><h1>Daily regional headlines</h1>
        <section><h2>Morning coverage</h2>
          #{(1..6).map do |number|
            "<article><h3><a href='/news/#{number}'>Independent regional headline number #{number}</a></h3>" \
              "<p>Local reporting explains the latest developments for residents in district #{number}.</p></article>"
          end.join}
        </section>
        <section><h2>Featured reports</h2><div class='carousel'><div class='track'>
          <article class='slide'><h3><a href='/feature/first'>First visible community report</a></h3><p>Current visible reporting.</p></article>
          <article class='slide'><h3><a href='/feature/second'>Partly visible community report</a></h3><p>Another visible report.</p></article>
          <article class='slide'><h3><a href='/feature/third'>Entirely off-screen community report</a></h3><p>Inactive carousel reporting.</p></article>
        </div></div></section>
        <section style='margin-top: 1800px'><h2>Later coverage</h2>
          <article><h3><a href='/later'>A complete report below the initial viewport</a></h3><p>Readers can scroll down to this report.</p></article>
        </section>#{extra}
      </main></body></html>
    HTML
  end

  it 'excludes fully clipped slides while retaining partially visible and below-fold records' do
    with_url_page('https://bulletin.example/', clipping_page) do |page|
      before = page.evaluate('document.body.outerHTML')
      markdown = extract_payload(page).fetch('markdown')
      expect(markdown).to include('https://bulletin.example/feature/first', 'https://bulletin.example/feature/second',
                                  'https://bulletin.example/later')
      expect(markdown).not_to include('/feature/third', 'Entirely off-screen community report', 'Inactive carousel reporting')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'keeps every materialized record in horizontally scrollable collections' do
    %w[auto scroll].each do |overflow|
      with_url_page('https://bulletin.example/', clipping_page(overflow: overflow)) do |page|
        markdown = extract_payload(page).fetch('markdown')
        %w[first second third].each { |name| expect(markdown).to include("https://bulletin.example/feature/#{name}") }
      end
    end
  end

  it 'preserves overflowing code tokens but excludes an entirely clipped code panel' do
    extra = <<~HTML
      <section><h2>Reading the data</h2><div style='width: 120px; overflow-x: hidden'>
        <pre><code>visible_prefix<span style='display: inline-block; margin-left: 500px'> + essential_suffix</span></code></pre>
      </div><div style='width: 120px; overflow-x: hidden'><pre style='margin-left: 500px; width: 200px'>inactive_code_panel()</pre></div></section>
    HTML
    with_url_page('https://bulletin.example/guide', clipping_page(extra: extra)) do |page|
      markdown = extract_payload(page).fetch('markdown')
      expect(markdown).to include('visible_prefix', 'essential_suffix')
      expect(markdown).not_to include('inactive_code_panel')
    end
  end
end
