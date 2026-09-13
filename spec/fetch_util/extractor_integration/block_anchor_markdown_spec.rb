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
end
