# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Complete selected linked heading records' do
  include_context 'extractor integration helpers'

  def parsed_heading_record_markdown(markdown)
    script = "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()))"
    output, error, status = Open3.capture3('python3', '-c', script, stdin_data: markdown)
    raise error unless status.success?

    Nokogiri::HTML5.fragment(output)
  end

  def heading_owner_probe_source
    root = ENV.fetch('FETCH_UTIL_BOUND_SOURCE_ROOT') { File.expand_path('../../..', __dir__) }
    directory = File.join(root, 'websieve')
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |name| name.empty? || name.start_with?('#') }
                 .map { |name| File.read(File.join(directory, name)) }.join("\n")
    raise 'private closure changed' unless source.scan('})(window);').length == 1

    source.sub('})(window);', <<~JS)
      window.selectedLinkedHeadingRecordProbe = function() {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var source = document.getElementById('publication');
            var before = source.outerHTML;
            var root = visibleListClone(source);
            cleanupListRoot(root);
            var items = extractFallbackHeadlineItems(root);
            var result = {
              markdown: listMarkdown(items),
              items: items.map(function(item) {
                return {
                  text: item.text, url: item.url,
                  card: item.card && item.card.outerHTML,
                  source: item.sourceNode && item.sourceNode.outerHTML,
                  headingRecord: !!item.sourceOrderedHeadingCard,
                  repeatedRecord: !!item.sourceOrderedRepeatedRecord
                };
              }),
              sourceUnchanged: source.outerHTML === before
            };
            root.replaceChildren();
            return result;
          })({});
        })({});
      };
      })(window);
    JS
  end

  def physical_heading_record(title, rank: 1, description: 'The complete report keeps its independently authored description.')
    <<~HTML
      <div class="feature-summary">
        <a href="https://records.example.test/report?edition=2&amp;view=complete#record"><h#{rank}>#{title}</h#{rank}>
          <p>#{description} <span class="author">By Ari Reader</span></p>
        </a>
      </div>
    HTML
  end

  def with_heading_owner_probe(material)
    html = "<title>Reference publication</title><main id='publication'>#{material}</main>"
    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: heading_owner_probe_source)
      observation = page.evaluate('selectedLinkedHeadingRecordProbe()')
      expect(observation.fetch('sourceUnchanged')).to eq(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield observation, parsed_heading_record_markdown(observation.fetch('markdown'))
    end
  end

  it 'retains a linked physical H1 and its complete owned paragraph as separate source roles' do
    title = 'A physically owned lead report'
    with_heading_owner_probe(physical_heading_record(title)) do |observation, rendered|
      expect(observation.fetch('items').map { |item| item.fetch('text') }).to eq([title])
      expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(
        ['https://records.example.test/report?edition=2&view=complete#record']
      )
      expect(rendered.text).to include('The complete report keeps its independently authored description.', 'By Ari Reader')
      expect(rendered.css('h1').map(&:text)).to eq([title])
      expect(rendered.css('p').map { |node| node.text.strip }).to eq(
        ['The complete report keeps its independently authored description. By Ari Reader']
      )
    end
  end

  it 'retains independent equal-destination heading records and their own prose in physical order' do
    material = physical_heading_record('First independent account', rank: 2, description: 'The first complete account remains separate.') +
               physical_heading_record('Second independent account', rank: 3, description: 'The second complete account remains separate.')
    with_heading_owner_probe(material) do |observation, rendered|
      expect(observation.fetch('items').map { |item| item.fetch('text') }).to eq(
        ['First independent account', 'Second independent account']
      )
      expect(rendered.css('a[href]').map { |node| node['href'] }).to eq(
        Array.new(2, 'https://records.example.test/report?edition=2&view=complete#record')
      )
      expect(rendered.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text] }).to eq(
        [['h2', 'First independent account'], ['h3', 'Second independent account']]
      )
      expect(rendered.css('p').map { |node| node.text.strip }).to eq(
        ['The first complete account remains separate. By Ari Reader', 'The second complete account remains separate. By Ari Reader']
      )
    end
  end

  it 'does not turn navigation or hidden records into an authored heading record' do
    record = physical_heading_record('An excluded interface title')
    ["<nav>#{record}</nav>", "<div hidden>#{record}</div>", "<div style='display:none'>#{record}</div>"].each do |material|
      with_heading_owner_probe(material) do |observation, rendered|
        expect(observation.fetch('items')).to be_empty
        expect(rendered.text.strip).to eq('')
      end
    end
  end

  it 'does not claim wrapper material outside the selected complete anchor' do
    [
      '<p>Independent prose belongs outside the selected record.</p>',
      '<span id="independent-target"></span>'
    ].each do |outside|
      material = physical_heading_record('A bounded heading record').sub("  </a>\n", "  </a>\n#{outside}\n")
      with_heading_owner_probe(material) do |observation, rendered|
        expect(observation.fetch('items').length).to eq(1)
        expect(observation.fetch('items').first.fetch('headingRecord')).to eq(false)
        expect(observation.fetch('items').first.fetch('card')).to include(outside)
        expect(rendered.css('h1')).to be_empty
      end
    end
  end
end
