# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil complete responsive image references' do
  include_context 'extractor integration helpers'

  def with_responsive_evidence(image)
    html = <<~HTML
      <!doctype html><html><head><title>Responsive evidence</title>
      <link rel="canonical" href="https://responsive.example.test/report/"></head><body>
      <main><article><h1>Responsive evidence</h1>
      <p>The complete independently authored introduction identifies the chart and its supporting evidence without borrowing any interface material.</p>
      #{image}
      <p>The complete second reporting paragraph explains the comparison and retains its <a href="/sources/?part=one,two#records">source reference</a>.</p>
      <pre>first_code()

      last_code()</pre>
      <p>The complete concluding reporting paragraph preserves the findings and the remaining questions in their original order.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://responsive.example.test/report/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      parser = "import sys\nfrom markdown_it import MarkdownIt\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      parsed, error, status = Open3.capture3('python', '-c', parser, stdin_data: payload.fetch('markdown'))
      raise "independent Markdown parser failed: #{error}" unless status.success?

      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = Nokogiri::HTML5.fragment(parsed)
      yield native, markdown, payload
    ensure
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains every safe source-set candidate, descriptor, size and complete alternative text without inventing a selected source' do
    image = '<img srcset="/assets/plot,full.jpg?view=wide&amp;part=2#north 640w, /assets/plot-large.jpg?view=wide&amp;part=2#north 1280w" ' \
      'sizes="(max-width: 720px) 100vw, 720px" alt="Independent plot [north]">'
    with_responsive_evidence(image) do |native, markdown, payload|
      expected = 'https://responsive.example.test/assets/plot,full.jpg?view=wide&part=2#north 640w, ' \
        'https://responsive.example.test/assets/plot-large.jpg?view=wide&part=2#north 1280w'
      expect(native.css('img').map { |node| node['srcset'] }).to eq([expected])
      expect(markdown.css('img').map { |node| node['srcset'] }).to eq([expected])
      expect(markdown.at_css('img')['sizes']).to eq('(max-width: 720px) 100vw, 720px')
      expect(markdown.at_css('img')['alt']).to eq('Independent plot [north]')
      expect(markdown.at_css('img')['src']).to be_nil
      expect(markdown.css('pre').map { |node| node.text.delete_suffix("\n") }).to include("first_code()\n\nlast_code()")
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'keeps an independently linked source-set image and its complete query and fragment destination' do
    image = '<a href="/evidence/?part=one,two#panel"><img srcset="/assets/detail.jpg?crop=0,0,40,40 1x, ' \
      '/assets/detail-double.jpg?crop=0,0,80,80 2x" alt="Independent linked chart"></a>'
    with_responsive_evidence(image) do |native, markdown, _payload|
      destination = 'https://responsive.example.test/evidence/?part=one,two#panel'
      expected = 'https://responsive.example.test/assets/detail.jpg?crop=0,0,40,40 1x, ' \
        'https://responsive.example.test/assets/detail-double.jpg?crop=0,0,80,80 2x'
      expect(native.css('img').map { |node| node['srcset'] }).to eq([expected])
      owners = markdown.css('a').select { |node| node['href'] == destination }
      expect(owners.length).to eq(1)
      expect(owners.first.css('img').map { |node| node['srcset'] }).to eq([expected])
      expect(owners.first.at_css('img')['alt']).to eq('Independent linked chart')
      expect(markdown.css('p').map(&:text)).to include(
        'The complete independently authored introduction identifies the chart and its supporting evidence without borrowing any interface material.',
        'The complete concluding reporting paragraph preserves the findings and the remaining questions in their original order.'
      )
    end
  end

  it 'preserves independent identical resource occurrences in source order' do
    source_set = '/assets/shared-small.png 1x, /assets/shared-large.png 2x'
    image = "<figure><img srcset='#{source_set}' alt='First independent plot'><figcaption>First source caption.</figcaption></figure>" \
      "<figure><img srcset='#{source_set}' alt='Second independent plot'><figcaption>Second source caption.</figcaption></figure>"
    with_responsive_evidence(image) do |native, markdown, _payload|
      expected = native.css('img').map { |node| [node['srcset'], node['alt']] }
      expect(expected.length).to eq(2)
      expect(markdown.css('img').map { |node| [node['srcset'], node['alt']] }).to eq(expected)
      expect(markdown.text).to include('First source caption.', 'Second source caption.')
    end
  end

  it 'retains the explicit safe source and the existing ordinary image rendering' do
    image = '<img src="/assets/fallback.png?view=full#north" srcset="/assets/retina.png 2x" alt="Explicit fallback">'
    with_responsive_evidence(image) do |native, markdown, payload|
      source = 'https://responsive.example.test/assets/fallback.png?view=full#north'
      expect(native.at_css('img')['src']).to eq(source)
      expect(native.at_css('img')['srcset']).to eq('https://responsive.example.test/assets/retina.png 2x')
      expect(markdown.css('img').map { |node| [node['src'], node['alt']] }).to eq([[source, 'Explicit fallback']])
      expect(payload.fetch('markdown')).to include("![Explicit fallback](#{source})")
    end
  end

  it 'keeps all valid candidates while excluding unsafe destinations and invalid descriptors' do
    image = '<img srcset="javascript:alert(1) 1x, https://reader:secret@images.example.test/private.png 2x, ' \
      '/assets/safe.png?view=one,two#plot 3x, /assets/invalid.png 0x" sizes="100vw" alt="Safe source set">'
    with_responsive_evidence(image) do |native, markdown, payload|
      expected = 'https://responsive.example.test/assets/safe.png?view=one,two#plot 3x'
      expect(native.at_css('img')['srcset']).to eq(expected)
      expect(markdown.at_css('img')['srcset']).to eq(expected)
      expect(markdown.at_css('img')['sizes']).to eq('100vw')
      expect(payload.fetch('markdown')).not_to include('javascript:', 'reader:secret', '/private.png', '/invalid.png')
    end
  end

  it 'preserves literal image markup and token-like programs without exposing hidden or closed resources' do
    literal = "FETCHUTILRESPONSIVEIMAGE0END\n\n<img srcset=\"https://literal.example.test/a.png 1x\">"
    image = <<~HTML
      <img srcset="/assets/visible.png 1x, /assets/visible-double.png 2x" alt="Visible evidence">
      <div hidden><img srcset="/assets/hidden.png 1x" alt="Hidden evidence"></div>
      <details><summary>Deferred evidence</summary><img srcset="/assets/closed.png 1x" alt="Closed evidence"></details>
      <pre>FETCHUTILRESPONSIVEIMAGE0END

      &lt;img srcset="https://literal.example.test/a.png 1x"&gt;</pre>
    HTML
    with_responsive_evidence(image) do |_native, markdown, payload|
      expect(markdown.css('img').map { |node| node['alt'] }).to eq(['Visible evidence'])
      expect(markdown.css('pre').map { |node| node.text.delete_suffix("\n") }).to include(literal)
      expect(markdown.text).to include('Deferred evidence')
      expect(payload.fetch('markdown')).not_to include('/assets/hidden.png', '/assets/closed.png', 'data-fetchutil-responsive-image-token')
    end
  end

  it 'retains complete responsive images inside rich source tables without private markers' do
    image = <<~HTML
      <table><thead><tr><th>Evidence</th></tr></thead><tbody><tr><td>
        <p>Complete table evidence.</p><img srcset="/assets/table-small.png 1x, /assets/table-large.png 2x" sizes="50vw" alt="Table evidence">
        <ul><li>First complete observation.</li><li>Second complete observation.</li></ul>
      </td></tr></tbody></table>
    HTML
    with_responsive_evidence(image) do |native, markdown, payload|
      expected = native.at_css('table img')['srcset']
      expect(markdown.at_css('table img')['srcset']).to eq(expected)
      expect(markdown.at_css('table img')['sizes']).to eq('50vw')
      expect(markdown.css('table th').map(&:text)).to eq(['Evidence'])
      expect(markdown.css('table li').map(&:text)).to eq(['First complete observation.', 'Second complete observation.'])
      expect(payload.fetch('markdown')).not_to include('data-fetchutil-responsive-image-token')
    end
  end
end
