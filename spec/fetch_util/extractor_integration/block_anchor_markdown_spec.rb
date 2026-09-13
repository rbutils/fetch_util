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
end
