require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  it 'preserves download artifacts and supporting references in ordinary tables' do
    html = <<~HTML
      <html><head><title>Library downloads</title></head><body><main><article>
        <h1>Library downloads</h1>
        <p>Choose the development build while debugging your application, and the smaller production
           build for deployment. The corresponding source map connects optimized code to its source.</p>
        <table>
          <tr><td><a href="library.js">Development Version (1.6.0)</a></td><td>Includes diagnostic messages.</td></tr>
          <tr><td><a href="library-min.js">Production Version</a></td>
            <td>Compressed build with a <a href="library-min.map">Source Map</a>.</td></tr>
          <tr><td><a href="https://source.example.test/library.js">Edge Version</a></td>
            <td>See the <a href="/changes?tag=stable|next">change log</a> before upgrading.</td></tr>
        </table>
      </article></main></body></html>
    HTML

    extract_from_url('https://manual.example.test/downloads', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('[Development Version (1.6.0)](https://manual.example.test/library.js)')
      expect(markdown).to include('[Production Version](https://manual.example.test/library-min.js)')
      expect(markdown).to include('[Source Map](https://manual.example.test/library-min.map)')
      expect(markdown).to include('[Edge Version](https://source.example.test/library.js)')
      expect(markdown).to include('[change log](https://manual.example.test/changes?tag=stable%7Cnext)')
      expect(markdown).to include('Includes diagnostic messages.', 'Compressed build with a')
    end
  end

  it 'keeps visible table labels without promoting hidden or unsupported references' do
    html = <<~HTML
      <html><head><title>Reference matrix</title></head><body><main><article>
        <h1>Reference matrix</h1>
        <p>The matrix groups resources by their role in the development process. Consult the named
           reference when implementing each stage and retain the associated compatibility notes.</p>
        <table><thead><tr><th>Stage</th><th>Reference</th></tr></thead><tbody>
          <tr><td>Build</td><td><a href="/build">Build reference</a></td></tr>
          <tr><td>Inspect</td><td><a href="javascript:alert(1)">Local action</a></td></tr>
          <tr><td>Private</td><td><a href="https://name:secret@example.test/private">Private reference</a></td></tr>
          <tr hidden><td>Hidden</td><td><a href="/hidden">Hidden reference</a></td></tr>
        </tbody></table>
      </article></main></body></html>
    HTML

    extract_from_url('https://manual.example.test/reference', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('[Build reference](https://manual.example.test/build)', 'Local action', 'Private reference')
      expect(markdown).not_to include('javascript:', 'name:secret', 'Hidden reference', '/hidden')
    end
  end

  it 'keeps same-label table references with distinct destinations' do
    html = <<~HTML
      <html><head><title>Resource index</title></head><body><main><article>
        <h1>Resource index</h1>
        <p>The resource index provides independent implementation guides for each supported runtime.</p>
        <table><tr><th>Runtime</th><th>Guides</th></tr><tr><td>Ruby</td><td>
          <div><a href="/guides/basics">Read</a></div>
          <div><a href="/guides/advanced">Read</a></div>
          <div><a href="/guides/advanced">Read</a></div>
        </td></tr></table>
      </article></main></body></html>
    HTML

    extract_from_url('https://manual.example.test/resources', html, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(markdown).to include(
        '[Read](https://manual.example.test/guides/basics)',
        '[Read](https://manual.example.test/guides/advanced)'
      )
      expect(markdown.scan('https://manual.example.test/guides/advanced').length).to eq(1)
    end
  end
end
