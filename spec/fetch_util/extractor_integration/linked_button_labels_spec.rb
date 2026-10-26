# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil physically linked resource button labels' do
  include_context 'extractor integration helpers'

  def with_linked_button_evidence(material)
    html = <<~HTML
      <!doctype html><html><head><title>Reference publication</title>
      <meta name="generator" content="WordPress">
      <link rel="canonical" href="https://publication.example.test/resources/"></head><body>
      <main><article class="entry-content"><h1>Reference publication</h1>
      <p>The complete authored introduction explains the independent research resources and the evidence required to reproduce each comparison.</p>
      #{material}
      <pre><code>load_data("a,b")

      finish()</code></pre>
      <p>The complete authored conclusion preserves the limitations and remaining questions in their original order.</p>
      </article></main></body></html>
    HTML
    with_url_page('https://publication.example.test/resources/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      parser = "import sys\nfrom markdown_it import MarkdownIt\nprint(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
      parsed, error, status = Open3.capture3('python', '-c', parser, stdin_data: payload.fetch('markdown'))
      raise "independent Markdown parser failed: #{error}" unless status.success?

      yield Nokogiri::HTML5.fragment(payload.fetch('html')), Nokogiri::HTML5.fragment(parsed), payload
    ensure
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
    end
  end

  it 'retains each complete short resource label and destination in physical table order without merging equal links' do
    material = <<~HTML
      <table><thead><tr><th>Subject</th><th>Dataset</th><th>Reference</th></tr></thead><tbody>
      <tr><td>First cohort</td>
      <td><a href="https://resources.example.test/data?part=one,two&amp;mode=full#records"><button><i></i>Dataset A</button></a></td>
      <td><a href="https://resources.example.test/reference?version=2#method"><button>Dataset B</button></a></td></tr>
      <tr><td>Second cohort</td>
      <td><a href="https://resources.example.test/data?part=one,two&amp;mode=full#records"><button><i></i>Dataset A</button></a></td>
      <td><a href="https://resources.example.test/reference?version=2#method"><button>Dataset B</button></a></td></tr>
      </tbody></table>
    HTML
    expected = [
      ['https://resources.example.test/data?part=one,two&mode=full#records', 'Dataset A'],
      ['https://resources.example.test/reference?version=2#method', 'Dataset B'],
      ['https://resources.example.test/data?part=one,two&mode=full#records', 'Dataset A'],
      ['https://resources.example.test/reference?version=2#method', 'Dataset B']
    ]
    with_linked_button_evidence(material) do |native, markdown, payload|
      [native, markdown].each do |document|
        expect(document.css('a[href]').map { |link| [link['href'], link.text.strip] }).to eq(expected)
        expect(document.css('th').map(&:text)).to eq(%w[Subject Dataset Reference])
        expect(document.css('td').map { |cell| cell.text.strip }).to eq(
          ['First cohort', 'Dataset A', 'Dataset B', 'Second cohort', 'Dataset A', 'Dataset B']
        )
        expect(document.css('pre').map { |node| node.text.delete_suffix("\n") }).to eq(["load_data(\"a,b\")\n\nfinish()"])
      end
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'preserves the complete linked inline formatting, literal code and surrounding paragraph boundaries' do
    material = <<~HTML
      <p>First material <a href="https://resources.example.test/report?edition=2&amp;part=all#evidence"><button><strong>Read</strong> <em>details</em> <code>v2</code></button></a>
      between <a href="https://resources.example.test/report?edition=2&amp;part=all#evidence"><button><span>Open</span></button></a> tail.</p>
    HTML
    destination = 'https://resources.example.test/report?edition=2&part=all#evidence'
    with_linked_button_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('a[href]').map { |link| [link['href'], link.text.strip] }).to eq(
          [[destination, 'Read details v2'], [destination, 'Open']]
        )
        first = document.css('a[href]').first
        expect(first.css('strong').map(&:text)).to eq(['Read'])
        expect(first.css('em').map(&:text)).to eq(['details'])
        expect(first.css('code').map(&:text)).to eq(['v2'])
        expect(document.css('p').map { |paragraph| paragraph.text.gsub(/\s+/, ' ').strip }).to include(
          'First material Read details v2 between Open tail.',
          'The complete authored conclusion preserves the limitations and remaining questions in their original order.'
        )
      end
    end
  end

  it 'keeps interface, submission, local-toggle and unsafe buttons out of the resource-label path' do
    material = <<~HTML
      <button>Standalone action</button>
      <a href="javascript:alert(1)"><button>Unsafe action</button></a>
      <a href="https://user:secret@resources.example.test/private"><button>Credential action</button></a>
      <a href="#"><button>Local toggle</button></a>
      <a href="/submit"><button type="submit">Submit action</button></a>
      <a href="/reset"><button type="reset">Reset action</button></a>
      <a href="/panel"><button aria-controls="panel" aria-expanded="false">Panel action</button></a>
      <a href="/popup" aria-haspopup="dialog"><button>Popup action</button></a>
      <nav><a href="/menu"><button>Menu action</button></a></nav>
      <form><a href="/form"><button>Form action</button></a></form>
      <div id="panel">The independently authored panel explanation remains complete.</div>
    HTML
    excluded = [
      'Standalone action', 'Unsafe action', 'Credential action', 'Local toggle',
      'Submit action', 'Reset action', 'Panel action', 'Popup action', 'Menu action', 'Form action'
    ]
    with_linked_button_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        excluded.each { |label| expect(document.text).not_to include(label) }
        expect(document.text).to include('The independently authored panel explanation remains complete.')
        expect(document.css('a[href]').map { |link| link['href'] }).not_to include('javascript:alert(1)')
      end
    end
  end

  it 'preserves an authored named-fragment reference without treating it as an empty interface toggle' do
    material = '<p><a href="#program-reference"><button>Code</button></a></p>' \
      '<p id="program-reference">The complete independent program reference identifies the reproducible method.</p>'
    with_linked_button_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('a[href]').map { |link| [link['href'], link.text] }).to eq(
          [['https://publication.example.test/resources/#program-reference', 'Code']]
        )
        expect(document.text).to include('The complete independent program reference identifies the reproducible method.')
      end
    end
  end

  it 'retains visible closed-summary references while excluding hidden and closed-body resource labels' do
    material = <<~HTML
      <div hidden><a href="/hidden"><button>Hidden evidence</button></a></div>
      <div style="display:none"><a href="/styled-hidden"><button>Styled hidden evidence</button></a></div>
      <details><summary><a href="/summary?edition=2#record"><button>Summary evidence</button></a></summary>
      <a href="/closed"><button>Closed evidence</button></a></details>
    HTML
    with_linked_button_evidence(material) do |native, markdown, _payload|
      expected = [['https://publication.example.test/summary?edition=2#record', 'Summary evidence']]
      expect(native.css('a[href]').map { |link| [link['href'], link.text.strip] }).to eq(
        expected + [['https://publication.example.test/closed', '']]
      )
      closed = native.at_css('a[href="https://publication.example.test/closed"]')
      expect(closed.ancestors('details').length).to eq(1)
      expect(closed.ancestors('details').first['open']).to be_nil
      expect(markdown.css('a[href]').map { |link| [link['href'], link.text.strip] }).to eq(expected)
      [native, markdown].each do |document|
        expect(document.text).not_to include('Hidden evidence', 'Styled hidden evidence', 'Closed evidence')
      end
    end
  end

  it 'preserves complete image, title and native binding material while removing button interaction attributes' do
    material = '<p><a href="/image?view=full#evidence"><button id="resource-label" title="Complete resource title" ' \
      'onclick="window.exampleAction()" tabindex="0"><img src="/chart.png?view=wide#north" alt="Complete independent chart">' \
      '<strong>Chart</strong></button></a></p>'
    with_linked_button_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        owner = document.css('a[href]').find { |link| link['href'] == 'https://publication.example.test/image?view=full#evidence' }
        expect(owner).not_to be_nil
        expect(owner.css('strong').map(&:text)).to eq(['Chart'])
        expect(owner.css('img').map { |image| [image['src'], image['alt']] }).to eq(
          [['https://publication.example.test/chart.png?view=wide#north', 'Complete independent chart']]
        )
      end
      replacement = native.at_css('[id="resource-label"]')
      expect(native.css('[id="resource-label"]').length).to eq(1)
      expect(replacement['title']).to eq('Complete resource title')
      expect(replacement['onclick']).to be_nil
      expect(replacement['tabindex']).to be_nil
    end
  end

  it 'keeps literal button markup and complete program whitespace intact' do
    literal = "<a href=\"https://resources.example.test/program\"><button>Program label</button></a>\n\nfinish()"
    material = '<pre><code>&lt;a href="https://resources.example.test/program"&gt;&lt;button&gt;Program label&lt;/button&gt;&lt;/a&gt;' \
      "\n\nfinish()</code></pre>"
    with_linked_button_evidence(material) do |native, markdown, _payload|
      [native, markdown].each do |document|
        expect(document.css('pre').map { |node| node.text.delete_suffix("\n") }).to eq(
          [literal, "load_data(\"a,b\")\n\nfinish()"]
        )
        expect(document.css('a[href]')).to be_empty
      end
    end
  end
end
