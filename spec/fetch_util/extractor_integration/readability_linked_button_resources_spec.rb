# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil plain Readability linked button resources' do
  include_context 'extractor integration helpers'

  def with_readability_resource_evidence(material)
    introduction = 'The field archive describes the complete observations collected across independent monitoring sites. ' \
                   'Each published record explains its sampling method, uncertainty and relationship to the original measurements. ' \
                   'Researchers can reproduce the comparisons using the separately authored resource references below.'
    conclusion = 'The interpretation distinguishes observed changes from differences in measurement practice. ' \
                 'Every independent comparison remains available alongside its original limitations and complete provenance. ' \
                 'The archive does not substitute a summary for the underlying evidence or merge separately authored references.'
    html = <<~HTML
      <!doctype html><html><head><title>Plain field archive</title>
      <link rel="canonical" href="https://archive.example.test/field-notes/"></head><body>
      <main><article><h1>Plain field archive</h1>
      <p>#{introduction}</p>
      <section><h2>Observations</h2>
      <p>The observations include temperature, salinity and current measurements from distinct locations and seasons.
      Their independently recorded calibration histories explain which comparisons are directly supported by the data.
      Missing observations remain explicit rather than being silently replaced by inferred values.</p></section>
      <section><h2>Resources</h2>
      <p>The publication provides full records and a separate catalogue so that readers can inspect the original evidence.
      Each physical resource reference belongs to the surrounding explanation, even when another occurrence has the same destination.</p>
      #{material}</section>
      <pre><code>load_records("north,south")

      compare_records()</code></pre>
      <section><h2>Interpretation</h2><p>#{conclusion}</p></section>
      </article></main></body></html>
    HTML
    expected_programs = Nokogiri::HTML5(html).css('pre').map(&:text)
    with_url_page('https://archive.example.test/field-notes/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      parser = "import sys\nfrom markdown_it import MarkdownIt\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      parsed, error, status = Open3.capture3('python', '-c', parser, stdin_data: payload.fetch('markdown'))
      raise "independent Markdown parser failed: #{error}" unless status.success?

      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      markdown = Nokogiri::HTML5.fragment(parsed)
      expect(payload.fetch('readerMode')).to be(true)
      [native, markdown].each do |document|
        expect(document.css('h1, h2, h3').map(&:text)).to include('Observations', 'Resources', 'Interpretation')
        expect(document.css('p').map { |node| node.text.gsub(/\s+/, ' ').strip }).to include(introduction, conclusion)
        expect(document.css('pre').map { |node| node.text.delete_suffix("\n") }).to eq(expected_programs)
      end
      yield native, markdown, payload
    ensure
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains every plain resource label and full destination before Readability can discard the button' do
    material = <<~HTML
      <div><a href="https://data.example.test/records?edition=full&amp;view=text#observations"><button>Access records</button></a></div>
      <div><a href="catalogue/?edition=full&amp;view=text#entries"><button>Access catalogue</button></a></div>
      <div><a href="https://data.example.test/records?edition=full&amp;view=text#observations"><button>Access records</button></a></div>
    HTML
    expected = [
      ['https://data.example.test/records?edition=full&view=text#observations', 'Access records'],
      ['https://archive.example.test/field-notes/catalogue/?edition=full&view=text#entries', 'Access catalogue'],
      ['https://data.example.test/records?edition=full&view=text#observations', 'Access records']
    ]
    with_readability_resource_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('a[href]').map { |node| [node['href'], node.text.strip] }).to eq(expected)
      end
    end
  end

  it 'retains complete linked inline material and native bindings while removing button interaction attributes' do
    material = <<~HTML
      <div><a href="/report?edition=2&amp;part=all#evidence"><button type="button" id="complete-report" title="Complete report reference"
      onclick="window.exampleAction()" tabindex="0"><strong>Read</strong> <em>evidence</em> <code>v2</code></button></a></div>
    HTML
    with_readability_resource_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('a[href]').map { |node| [node['href'], node.text.strip] }).to eq(
          [['https://archive.example.test/report?edition=2&part=all#evidence', 'Read evidence v2']]
        )
        link = document.css('a[href]').first
        expect(link.css('strong').map(&:text)).to eq(['Read'])
        expect(link.css('em').map(&:text)).to eq(['evidence'])
        expect(link.css('code').map(&:text)).to eq(['v2'])
      end
      expect(native.css('[id="complete-report"]').length).to eq(1)
      replacement = native.at_css('[id="complete-report"]')
      expect(replacement['title']).to eq('Complete report reference')
      expect(replacement['onclick']).to be_nil
      expect(replacement['tabindex']).to be_nil
    end
  end

  it 'keeps form actions, unsafe toggles, hidden and closed labels out while preserving literal programs' do
    material = <<~HTML
      <form><a href="/submit"><button type="submit">Submit observations</button></a></form>
      <nav><a href="/menu"><button>Navigation action</button></a></nav>
      <a href="javascript:alert(1)"><button>Unsafe action</button></a>
      <a href="#"><button>Local toggle</button></a>
      <a href="/panel"><button aria-controls="panel" aria-expanded="false">Panel action</button></a>
      <div hidden><a href="/hidden"><button>Hidden reference</button></a></div>
      <details><summary>Supplementary methods</summary><a href="/closed"><button>Closed reference</button></a></details>
      <pre><code>&lt;a href="https://program.example.test/only"&gt;&lt;button&gt;Program label&lt;/button&gt;&lt;/a&gt;</code></pre>
    HTML
    with_readability_resource_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.text).not_to include(
          'Submit observations', 'Navigation action', 'Unsafe action', 'Local toggle', 'Panel action', 'Hidden reference', 'Closed reference'
        )
        expect(document.css('a[href]').map { |node| node['href'] }).not_to include('javascript:alert(1)')
        expect(document.css('pre').map { |node| node.text.delete_suffix("\n") }).to include(
          '<a href="https://program.example.test/only"><button>Program label</button></a>'
        )
      end
    end
  end
end
