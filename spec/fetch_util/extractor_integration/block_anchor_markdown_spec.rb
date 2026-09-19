# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  def block_anchor_page(body)
    <<~HTML
      <html><head><title>Application integration guide</title></head><body><main>
      <h1>Application integration guide</h1>
      <p>Connect your application to these components and editor integrations.
      Each resource provides a working implementation and documentation for the integration.</p>
      #{body}
      <p>Choose the integration that matches your project and follow its configuration instructions.</p>
      </main></body></html>
    HTML
  end

  it 'preserves destinations on named cards containing custom media and block labels' do
    html = block_anchor_page(<<~HTML)
      <a href="https://components.example.test/spectrum/#usage">
        <lazy-svg label="Spectrum"></lazy-svg>
        <div><span>Spectrum components</span></div>
      </a>
      <a href="https://components.example.test/controls/">
        <div><strong>Application controls</strong></div>
        <p>Accessible component examples</p>
      </a>
    HTML

    result = extract_from_url('https://guide.example.test/integration', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include('[Spectrum components](https://components.example.test/spectrum/#usage)')
    expect(result.fetch('markdown')).to include('https://components.example.test/controls/', 'Application controls', 'Accessible component examples')
  end

  it 'keeps image and descriptive text cards linked without admitting unsafe destinations' do
    html = block_anchor_page(<<~HTML)
      <a href="https://editors.example.test/plugin">
        <img src="https://images.example.test/editor.svg" alt="Editor logo">
        <strong>Editor integration</strong><div>Install the editor plugin</div>
      </a>
      <a href="javascript:alert(1)"><div>Unsafe integration</div></a>
      <a href="https://user:secret@editors.example.test/private"><div>Private integration</div></a>
      <a href="https://editors.example.test/hidden" hidden><div>Hidden integration</div></a>
    HTML

    result = extract_from_url('https://guide.example.test/editors', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include('https://editors.example.test/plugin', 'Editor integration', 'Install the editor plugin')
    expect(result.fetch('markdown')).to include('![Editor logo](https://images.example.test/editor.svg)')
    expect(result.fetch('markdown')).not_to include('javascript:', 'user:secret', 'Hidden integration')
  end

  it 'keeps repeated article-card fields separate while linking their owned titles' do
    cards = 4.times.map do |index|
      <<~HTML
        <div class="field__item">
          <article class="media-card">
            <a href="/news/story-#{index}" title="Story #{index} details">
              <div class="media"><img src="/images/story-#{index}.jpg" alt="Story #{index} preview"></div>
              <div class="wrapper">
                <p class="section-text" data-fetch-util-structured-card-field="page-authored">Research</p>
                <div class="card__title">Complete research story #{index}</div>
                <span class="field field--name-created field--label-hidden"><time datetime="2026-09-#{index + 10}">#{index + 10} September 2026</time></span>
              </div>
            </a>
          </article>
        </div>
      HTML
    end.join
    html = block_anchor_page("<section><h2>Latest research</h2><div class='cards'>#{cards}</div></section>")

    result = nil
    with_url_page('https://guide.example.test/research', html) do |page|
      source_html = page.evaluate('document.body.innerHTML')
      result = extract_payload(page, reader_mode: false)
      expect(page.evaluate('document.body.innerHTML')).to eq(source_html)
    end
    markdown = result.fetch('markdown')

    4.times do |index|
      image = "![Story #{index} preview](https://guide.example.test/images/story-#{index}.jpg)"
      title = "[Complete research story #{index}](https://guide.example.test/news/story-#{index} \"Story #{index} details\")"
      date = "#{index + 10} September 2026"
      expect(markdown).to include(image, title, date)
      expect(markdown.index(image)).to be < markdown.index(title)
      expect(markdown.index(title)).to be < markdown.index(date)
      expect(markdown.scan("https://guide.example.test/news/story-#{index}").length).to eq(1)
    end
    expect(markdown.scan(/^Research$/).length).to eq(4)
    expect(markdown).not_to include("\uE000fetch-util-card-field:", 'data-fetch-util-structured-card-field')
    expect(result.fetch('textContent')).not_to include("\uE000fetch-util-card-field:")
  end

  it 'leaves ambiguous and incomplete block-label links on the established compact path' do
    html = block_anchor_page(<<~HTML)
      <div class="cards">
        <article><a href="/ambiguous"><img src="/ambiguous.jpg" alt="Ambiguous preview">
          <p class="section-text">Research</p><div class="title">First title field</div>
          <div class="headline">Second title field</div><time>10 September 2026</time></a></article>
        <article><a href="/incomplete"><img src="/incomplete.jpg" alt="Incomplete preview">
          <div class="title">Incomplete card title</div><time>11 September 2026</time></a></article>
      </div>
    HTML

    result = extract_from_url('https://guide.example.test/ambiguous-cards', html, reader_mode: false) { |payload| payload }
    markdown = result.fetch('markdown')

    expect(markdown).to include(
      '[![Ambiguous preview](https://guide.example.test/ambiguous.jpg) Research First title field Second title field 10 September 2026](https://guide.example.test/ambiguous)',
      '[![Incomplete preview](https://guide.example.test/incomplete.jpg) Incomplete card title 11 September 2026](https://guide.example.test/incomplete)'
    )
  end

  it 'preserves every repeated structured card without a presentation cap' do
    cards = 125.times.map do |index|
      <<~HTML
        <div class="field__item"><article><a href="/reports/#{index}">
          <img src="/reports/#{index}.jpg" alt="Report #{index}">
          <p class="section-text">Research</p>
          <div class="card__title">Complete research report #{index}</div>
          <time>#{index + 1} September 2026</time>
        </a></article></div>
      HTML
    end.join
    html = "<main><section><h2>Research reports</h2><div class='cards'>#{cards}</div></section></main>"

    with_url_page('https://guide.example.test/reports', html) do |page|
      root = File.expand_path('../../..', __dir__)
      source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject do |line|
        line.empty? || line.start_with?('#')
      end.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
      source = source.sub('})(window);', <<~JS)
        global.structuredCardProbe = function() {
          const source = document.querySelector('main');
          const root = source.cloneNode(true);
          preserveStructuredCardLinks(root);
          return {
            outerLinks: root.querySelectorAll('article > a[href]').length,
            titleLinks: Array.from(root.querySelectorAll('article .card__title > a[href]')).map(function(link) {
              return link.href;
            }),
            sourceOuterLinks: source.querySelectorAll('article > a[href]').length,
            sourceTitleLinks: source.querySelectorAll('article .card__title > a[href]').length
          };
        };
        })(window);
      JS
      page.add_script_tag(content: source)

      result = page.evaluate('structuredCardProbe()')
      expect(result.fetch('outerLinks')).to eq(0)
      expect(result.fetch('titleLinks')).to eq(125.times.map { |index| "https://guide.example.test/reports/#{index}" })
      expect(result).to include('sourceOuterLinks' => 125, 'sourceTitleLinks' => 0)
    end
  end

  it 'links a whole article card through its heading while preserving paragraphs and images' do
    html = block_anchor_page(<<~HTML)
      <a href="https://charts.example.test/plot?source=guide&amp;campaign=examples">
        <article><h2>Powering <em>quick charts</em></h2>
        <p>This higher-level interface provides chart primitives built on the core library.</p>
        <p>Try the plotting library</p><img src="/plot.svg" alt="Chart preview"></article>
      </a>
      <a href="/workspace"><section><h3>Collaborative workspace</h3>
        <p>Build shared applications with the rest of your team.</p></section></a>
    HTML

    result = extract_from_url('https://guide.example.test/cards', html, reader_mode: false) { |payload| payload }
    markdown = result.fetch('markdown')
    expect(markdown).to include('## [Powering _quick charts_](https://charts.example.test/plot?source=guide&campaign=examples)')
    expect(markdown).to include('### [Collaborative workspace](https://guide.example.test/workspace)')
    expect(markdown).to include("core library.\n\nTry the plotting library", '![Chart preview](https://guide.example.test/plot.svg)')
  end

  it 'preserves heading card labels while rejecting hidden and unsafe destinations' do
    html = block_anchor_page(<<~HTML)
      <a href="javascript:alert(1)"><h2>Untrusted chart integration</h2><p>Visible instructions remain available.</p></a>
      <a href="https://user:secret@charts.example.test/private"><h3>Private chart integration</h3></a>
      <a href="/hidden" hidden><h2>Hidden chart integration</h2></a>
    HTML

    result = extract_from_url('https://guide.example.test/card-labels', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include('Untrusted chart integration', 'Visible instructions remain available.')
    expect(result.fetch('markdown')).not_to include('javascript:', 'user:secret', 'Hidden chart integration')
  end

  it 'preserves accessible names on icon-only resources without replacing visible labels' do
    html = block_anchor_page(<<~HTML)
      <a href="https://tools.example.test/prompt?q=integration" aria-label="Open integration prompt">
        <span aria-hidden="true"><svg><path d="M0 0h10v10z"></path></svg></span>
      </a>
      <a href="/manual" aria-label="Open the full manual">Read the manual</a>
      <a href="/print" aria-label="Print"><svg></svg></a>
      <a href="/hidden" aria-label="Hidden tool" hidden><svg></svg></a>
      <a href="javascript:alert(1)" aria-label="Untrusted tool"><svg></svg></a>
    HTML

    result = extract_from_url('https://guide.example.test/icon-links', html, reader_mode: false) { |payload| payload }
    markdown = result.fetch('markdown')
    expect(markdown).to include('[Open integration prompt](https://tools.example.test/prompt?q=integration)')
    expect(markdown).to include('[Read the manual](https://guide.example.test/manual)')
    expect(markdown).not_to include('Open the full manual', '[Print]', 'Hidden tool', 'javascript:', 'Untrusted tool')
  end

  it 'keeps text links valid when a block-level figure contains their decorative icon' do
    html = block_anchor_page(<<~HTML)
      <a href="/report"><span>Read the report</span>
        <figure><span aria-hidden="true"><svg><path d="M0 0h10v10z"></path></svg></span></figure>
      </a>
    HTML

    result = extract_from_url('https://guide.example.test/report-link', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include('[Read the report](https://guide.example.test/report)')
  end
end
