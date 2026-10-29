# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'cgi'

RSpec.describe 'Complete standalone list-context programs' do
  include_context 'extractor integration helpers'

  def context_program(value)
    "<pre><code>#{CGI.escapeHTML(value)}</code></pre>"
  end

  def program_records
    6.times.map do |index|
      "<a data-record='#{index}' href='https://records.example.test/#{index}?view=full&amp;edition=2#complete'>" \
        "<h2>Independent record #{index}</h2><p>Record #{index} retains its whole independently authored explanation.</p></a>"
    end.join
  end

  def program_page(context)
    "<html><head><title>Complete source programs</title></head><body><main id='publication'>" \
      "<section><h2>Independent records</h2>#{program_records}</section>#{context}</main></body></html>"
  end

  def program_markdown(markdown)
    script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise error unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def program_probe_source
    root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT') { File.expand_path('../../..', __dir__) }
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |name| name.empty? || name.start_with?('#') }
                 .map { |name| File.read(File.join(root, 'websieve', name)) }.join("\n")
    raise 'private closure changed' unless source.scan('})(window);').length == 1

    source.sub('})(window);', <<~JS)
      window.listContextProgramProbe = function() {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var root = document.getElementById('publication');
            var items = Array.from(root.querySelectorAll('a[data-record]')).map(function(link) {
              return { card: link, sourceNode: link, url: link.href,
                text: link.querySelector('h2').textContent, sourceOrderedHeadingCard: true };
            });
            var parts = listDescriptionParts(root, items, { includeInlineProse: true,
              preserveUnrepresentedText: true, sectionLabels: ['Independent records'] });
            return { markdown: parts.map(function(part) { return part.markdown; }).join('\\n\\n'),
              sources: parts.map(function(part) { return part.node.outerHTML; }) };
          })({});
        })({});
      };
      })(window);
    JS
  end

  def with_program_context(context, record_program: nil)
    html = program_page(context)
    html = html.sub('</p></a>', "</p>#{context_program(record_program)}</a>") if record_program
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: program_probe_source)
      observation = page.evaluate('listContextProgramProbe()')
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield observation, program_markdown(observation.fetch('markdown'))
    end
  end

  it 'retains independent identical programs and complete prose in physical order without text-length limits' do
    literal = "  query(\"<kept>\");\n\nconst fence = \"``` & \\\\ exact\";\n#{"0123456789" * 215}\n  finish();"
    paragraph = 'The complete intervening paragraph describes the independently repeated program.'
    context = "#{context_program(literal)}<p>#{paragraph}</p>#{context_program(literal)}"
    with_program_context(context) do |_observation, rendered|
      expect(rendered.element_children.map(&:name)).to eq(%w[pre p pre])
      expect(rendered.css('pre').map(&:text)).to eq(["#{literal}\n", "#{literal}\n"])
      expect(rendered.css('p').map(&:text)).to eq([paragraph])
    end
  end

  it 'retains exact code-target offsets and complete linked destinations without exposing hidden program text' do
    context = <<~HTML
      <pre><code><a id="program-start" style="display:none"></a>before <a href="https://source.example.test/api?edition=2&amp;view=full#run">run</a>

      after</code></pre>
      <pre><code>left<span hidden>withheld instruction</span>right</code></pre>
    HTML
    with_program_context(context) do |_observation, rendered|
      expect(rendered.css('pre').map(&:text)).to eq(["before run\n\nafter", "leftright\n"])
      target = rendered.at_css('pre a#program-start')
      expect(target).not_to be_nil
      expect(target.previous_sibling).to be_nil
      expect(rendered.css('pre a[href]').map { |node| [node.text, node['href']] }).to eq(
        [['run', 'https://source.example.test/api?edition=2&view=full#run']]
      )
      expect(rendered.text).not_to include('withheld instruction')
    end
  end

  it 'keeps summary and open programs while excluding hidden interfaces and already owned programs' do
    context = "<details><summary>#{context_program("summary_program()")}</summary>#{context_program("closed_program()")}</details>" \
      "<details open><summary>Open context</summary>#{context_program("open_program()")}</details>" \
      "<blockquote>#{context_program("quoted_program()")}</blockquote>" \
      "<div hidden>#{context_program("hidden_program()")}</div>" \
      "<nav>#{context_program("navigation_program()")}</nav><form>#{context_program("form_program()")}</form>"
    with_program_context(context, record_program: 'record_owned_program()') do |_observation, rendered|
      expect(rendered.css('pre').map(&:text)).to eq(["summary_program()\n", "open_program()\n", "quoted_program()\n"])
      expect(rendered.css('blockquote pre').length).to eq(1)
      expect(rendered.text).not_to include('closed_program', 'hidden_program', 'navigation_program', 'form_program', 'record_owned_program')
    end
  end

  it 'retains a complete standalone program after the six physical records in the compiled result' do
    peers = 5.times.map do |index|
      "<a class='story-card' href='/reports/#{index}?edition=2&amp;view=full#details'>" \
        "<h2>Independent complete report #{index}</h2>" \
        "<p>Report #{index} keeps every authored word and its own independently declared destination.</p></a>"
    end.join
    literal = "query(\"<kept>\")\n\nreturn \"a&b\""
    html = <<~HTML
      <html><head><title>Latest reports | Reference publication</title>
      <link rel="canonical" href="https://publication.example.test/">
      <meta name="generator" content="WordPress"><meta property="og:type" content="website"></head>
      <body><main id="publication"><div class="feature-summary">
      <a href="https://records.example.test/report?edition=2&amp;view=complete#record"><h1>A physically owned lead report</h1>
      <p>The complete report keeps its independently authored description. <span class="author">By Ari Reader</span></p></a></div>
      <section><h2>Latest independent reports</h2><div class="story-grid">#{peers}</div></section>
      #{context_program(literal)}<p>The final authored limitations remain complete.</p></main></body></html>
    HTML
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))
      rendered = program_markdown(payload.fetch('markdown'))
      expected_urls = [
        'https://records.example.test/report?edition=2&view=complete#record',
        *5.times.map { |index| "https://publication.example.test/reports/#{index}?edition=2&view=full#details" }
      ]
      [native, rendered].each do |root|
        expect(root.css('h1').map(&:text)).to eq(['A physically owned lead report'])
        expect(root.css('h2').map(&:text)).to eq(['Latest independent reports', *5.times.map { |index| "Independent complete report #{index}" }])
        expect(root.css('a[href]').map { |node| node['href'] }).to eq(expected_urls)
      end
      expect(native.css('pre').map(&:text)).to eq([literal])
      expect(rendered.css('pre').map(&:text)).to eq(["#{literal}\n"])
      expect(rendered.element_children.to_a.last(2).map(&:name)).to eq(%w[pre p])
      expect(rendered.element_children.last.text).to eq('The final authored limitations remain complete.')
    end
  end
end
