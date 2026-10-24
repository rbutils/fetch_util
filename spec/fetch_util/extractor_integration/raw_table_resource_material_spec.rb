# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'
require 'nokogiri'

RSpec.describe 'Raw table resource resolution' do
  include_context 'extractor integration helpers'

  def raw_table_resource_probe
    root = File.expand_path('../../../websieve', __dir__)
    paths = File.readlines(File.join(root, 'manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |name| File.read(File.join(root, name)) }.join("\n")
    body = <<~JS
      window.rawTableResources = withComposedDomRead(function(options) {
        return markdownFor(document.body.innerHTML, false, options.allowMailto, true);
      });
    JS
    raise 'private renderer boundary differs' unless source.scan('})(window);').length == 1

    source.sub('})(window);', "#{body}})(window);")
  end

  def with_raw_table(html, allow_mailto: true)
    with_url_page('https://publication.example.test/docs/manual/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      FetchUtil::Extractor.new.send(:inject_vendor_assets, page)
      page.add_script_tag(content: raw_table_resource_probe)
      markdown = page.evaluate("rawTableResources({allowMailto: #{allow_mailto ? "true" : "false"}})")
      rendered = Nokogiri::HTML.fragment(markdown)
      yield rendered, markdown
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'resolves every independent relative reference and image without changing program values' do
    program = "source = '../literal?token=a&part=b'\n\nfinish('<value>')"
    html = <<~HTML
      <table><tr><td><p>Published references:</p><p>
      <a href='../field?mode=all&amp;part=2#entry'>First reference</a>
      <a href='../field?mode=all&amp;part=2#entry'>Independent reference</a>
      <img src='../../diagram.svg' alt='Published diagram'></p></td>
      <td><pre><code>#{CGI.escapeHTML(program)}</code></pre></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.css('a').map { |link| [link.text, link['href']] }).to eq(
        [
          ['First reference', 'https://publication.example.test/docs/field?mode=all&part=2#entry'],
          ['Independent reference', 'https://publication.example.test/docs/field?mode=all&part=2#entry']
        ]
      )
      expect(rendered.css('img').map { |image| [image['src'], image['alt']] }).to eq(
        [['https://publication.example.test/diagram.svg', 'Published diagram']]
      )
      expect(rendered.css('pre code').map(&:text)).to eq([program])
    end
  end

  it 'retains complete picture candidates with comma-bearing URLs and their descriptors' do
    html = <<~HTML
      <table><tr><td><p>Published pictures.</p><p><picture>
      <source srcset='../cdn-cgi/image/width=400,fit=scale-down/photo.jpg 400w, ../photo-large.jpg 800w'>
      <img src='../photo.jpg' srcset='../photo.jpg 1x, ../photo@2x.jpg 2x' alt='Field photograph'>
      </picture></p></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.at_css('source')['srcset']).to eq(
        'https://publication.example.test/docs/cdn-cgi/image/width=400,fit=scale-down/photo.jpg 400w, ' \
        'https://publication.example.test/docs/photo-large.jpg 800w'
      )
      image = rendered.at_css('img')
      expect(image['src']).to eq('https://publication.example.test/docs/photo.jpg')
      expect(image['srcset']).to eq(
        'https://publication.example.test/docs/photo.jpg 1x, https://publication.example.test/docs/photo@2x.jpg 2x'
      )
      expect(image['alt']).to eq('Field photograph')
    end
  end

  it 'applies the existing explicit article contact permission to the preserved snapshot' do
    html = '<table><tr><td><p>Published contact.</p><p><a href="mailto:editor@publication.example.test">' \
           'Editorial contact</a></p></td></tr></table>'
    with_raw_table(html, allow_mailto: true) do |rendered, _markdown|
      expect(rendered.at_css('a')['href']).to eq('mailto:editor@publication.example.test')
    end
    with_raw_table(html, allow_mailto: false) do |rendered, _markdown|
      expect(rendered.at_css('a').text).to eq('Editorial contact')
      expect(rendered.at_css('a')['href']).to be_nil
    end
  end

  it 'uses the existing inert resource normalization on root and descendant attributes' do
    html = <<~HTML
      <table background='../grid.svg'><tr><td><p>Published text.</p><p>
      <a id='named-target' href='javascript:alert(1)'>Retained label</a>
      <img src='../diagram.svg' alt='Declared diagram' onerror='alert(2)'></p></td></tr></table>
    HTML
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.at_css('table')['background']).to eq('https://publication.example.test/docs/grid.svg')
      link = rendered.at_css('a#named-target')
      expect([link.text, link['id'], link['href']]).to eq(['Retained label', 'named-target', nil])
      expect(rendered.at_css('img')['src']).to eq('https://publication.example.test/docs/diagram.svg')
      expect(rendered.css('[onerror], script')).to be_empty
    end
  end

  it 'leaves encoded URL-looking program text and all blank lines literal' do
    program = "<a href='../literal'>literal</a>\n\n<img src='../literal.svg'>\n"
    html = "<table><tr><td><pre><code>#{CGI.escapeHTML(program)}</code></pre></td>" \
           '<td><p>Complete unrelated text.</p></td></tr></table>'
    with_raw_table(html) do |rendered, _markdown|
      expect(rendered.css('pre code').map(&:text)).to eq([program])
      expect(rendered.css('a, img')).to be_empty
      expect(rendered.css('td').map(&:text)).to eq([program, 'Complete unrelated text.'])
    end
  end
end
