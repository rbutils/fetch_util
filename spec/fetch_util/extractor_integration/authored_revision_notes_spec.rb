# frozen_string_literal: true

require 'spec_helper'
require 'cgi'
require 'nokogiri'
require 'open3'

RSpec.describe 'FetchUtil complete authored publication revision notes' do
  include_context 'extractor integration helpers'

  def revision_destination
    'https://publication.example.test/history/782404fbe62?edition=full&view=text#revision'
  end

  def revision_note
    "Last modified September 16, 2026: <a href=\"#{CGI.escapeHTML(revision_destination)}\">Complete published revision (782404fbe62)</a>"
  end

  def revision_document(content, docs: false)
    prose = (1..10).map do |index|
      "<p>Complete authored explanation #{index} preserves every public result, its original references and all independently published context.</p>"
    end.join
    generator = docs ? '<meta name="generator" content="Hugo 0.140.0">' : ''
    owner = docs ? 'div class="td-content"' : 'article'
    close = docs ? 'div' : 'article'
    '<html lang="en"><head><title>Complete publication history</title>' \
      "#{generator}</head><body><main><#{owner}><h1>Complete publication history</h1>" \
      "#{prose}#{content}</#{close}></main></body></html>"
  end

  def independently_parsed_revision(markdown)
    script = "import sys; from markdown_it import MarkdownIt; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()), end='')"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise "independent revision parser failed: #{error}" unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def observe_revision(content, docs: false)
    html = revision_document(content, docs: docs)
    path = docs ? '/documentation/guide/' : '/reports/history'
    with_url_page("https://publication.example.test#{path}", html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = FetchUtil::Extractor.new.extract(page)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      parsed = independently_parsed_revision(payload.fetch('markdown'))
      (1..10).each { |index| expect(parsed.text).to include("Complete authored explanation #{index}") }
      yield native, parsed, payload
    end
  end

  def expect_complete_revision(native, parsed, count: 1)
    [native, parsed].each do |root|
      links = root.css('a[href]').select { |node| node['href'] == revision_destination }
      expect(links.map(&:text)).to eq(Array.new(count, 'Complete published revision (782404fbe62)'))
      expect(root.text.scan('Last modified September 16, 2026:').length).to eq(count)
    end
  end

  it 'keeps the complete ordinary article revision date, context and full independent destination' do
    observe_revision("<p class=\"publication-revision\">#{revision_note}</p>") do |native, parsed, _payload|
      expect_complete_revision(native, parsed)
    end
  end

  it 'keeps independently authored equal revision occurrences without text or destination deduplication' do
    content = "<p>#{revision_note}</p><p>Independent audit record follows the preceding publication note.</p><p>#{revision_note}</p>"
    observe_revision(content) { |native, parsed, _payload| expect_complete_revision(native, parsed, count: 2) }
  end

  it 'keeps a complete documentation revision owner and date alongside its full query and fragment' do
    observe_revision("<div class=\"td-page-meta__lastmod\">#{revision_note}</div>", docs: true) do |native, parsed, _payload|
      expect_complete_revision(native, parsed)
    end
  end

  it 'preserves a complete literal program containing the same dated revision text' do
    program = "Last modified September 16, 2026: literal_revision([item])\n  keep_exact_spaces()"
    observe_revision("<pre><code>#{CGI.escapeHTML(program)}</code></pre>") do |native, parsed, _payload|
      expect(native.at_css('pre code').text).to eq(program)
      expect(parsed.at_css('pre code').text).to eq("#{program}\n")
    end
  end

  it 'excludes genuinely hidden, navigation and feedback controls without publishing their revision destinations' do
    content = '<p style="display:none">Last modified September 16, 2026: <a href="https://hidden.example.test/revision">HIDDEN_REVISION_301</a></p>' \
      '<nav aria-label="Publication tools"><form><a href="https://interface.example.test/revision">NAVIGATION_REVISION_301</a></form></nav>' \
      '<form><button type="button">Send feedback</button><p>Last modified September 16, 2026: FORM_REVISION_301</p></form>'
    observe_revision(content) do |_native, parsed, _payload|
      expect(parsed.text).not_to include('HIDDEN_REVISION_301', 'NAVIGATION_REVISION_301', 'FORM_REVISION_301', 'Send feedback')
      expect(parsed.css('a[href]').map { |node| node['href'] }).not_to include(
        'https://hidden.example.test/revision', 'https://interface.example.test/revision'
      )
    end
  end

  it 'preserves ordinary inline revision prose that is not a standalone cleanup line' do
    text = 'The independent audit says Last modified September 16, 2026 and preserves the complete written explanation.'
    observe_revision("<p>#{text}</p>") do |native, parsed, _payload|
      expect(native.text).to include(text)
      expect(parsed.text).to include(text)
    end
  end

  it 'keeps a complete Source-owned bare publication date without admitting a form date' do
    text = 'Last modified September 16, 2026: Complete independently authored publication note.'
    observe_revision("<p>#{text}</p>") do |native, parsed, _payload|
      expect(native.text).to include(text)
      expect(parsed.text).to include(text)
    end
  end

  it 'does not use an equal ordinary note as authority for an additional form-owned occurrence' do
    content = "<p>#{revision_note}</p><form><p>#{revision_note}</p></form>"
    observe_revision(content) do |_native, parsed, _payload|
      expect(parsed.css('a[href]').count { |node| node['href'] == revision_destination }).to eq(1)
      expect(parsed.text.scan('Last modified September 16, 2026:').length).to eq(1)
    end
  end

  it 'retains a complete rich revision label and its inline literal identifier' do
    rich = revision_note.sub(
      'Complete published revision (782404fbe62)',
      '<strong>Complete published revision</strong> (<code>782404fbe62</code>)'
    )
    observe_revision("<p>#{rich}</p>") do |native, parsed, _payload|
      expect_complete_revision(native, parsed)
      expect(parsed.css('a[href] strong').map(&:text)).to eq(['Complete published revision'])
      expect(parsed.css('a[href] code').map(&:text)).to eq(['782404fbe62'])
    end
  end
end
