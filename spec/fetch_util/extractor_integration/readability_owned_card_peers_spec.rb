require 'cgi'
require 'nokogiri'

RSpec.describe 'Source-owned card peers in reader selection' do
  include_context 'extractor integration helpers'

  def owned_card_peer_source(same_destination: false, extra: '')
    second = same_destination ? '/records/first?mode=full#record' : '/records/second?mode=full#record'
    <<~HTML
      <html><head><title>Field research cards</title></head><body><main><article>
        <h1>Field research cards</h1>
        <section class="card-grid">
          <div class="card">
            <a href="/records/first?mode=full#record"><img src="/first.jpg" alt=""></a>
            <div><a href="/records/first?mode=full#record"><h3>First field record</h3></a>
              <p>This apparatus folds neatly inside its storage cabinet.</p></div>
          </div>
          <div class="card">
            <a href="#{second}"><figure><img src="/second.jpg" alt=""></figure></a>
            <div><a href="#{second}"><p>Second independent field record</p></a>
              <p>A brief science update from the laboratory.</p>#{extra}</div>
          </div>
        </section>
      </article></main></body></html>
    HTML
  end

  def with_owned_card_peers(html, reader_mode: true)
    with_url_page('https://publication.example.test/research/', html) do |page|
      before = page.evaluate('({html:document.body.outerHTML,text:document.body.innerText})')
      payload = extract_payload(page, reader_mode: reader_mode)
      retained = Nokogiri::HTML5.fragment(payload.fetch('html'))
      yield payload, retained
      expect(page.evaluate('({html:document.body.outerHTML,text:document.body.innerText})')).to eq(before)
    end
  end

  def expect_complete_owned_card_peers(retained, same_destination: false)
    second = same_destination ? 'first' : 'second'
    expect(retained.css('h1,h2,h3,h4,h5,h6').map { |node| [node.name, node.text] }).to eq(
      [['h1', 'Field research cards'], ['h3', 'First field record']]
    )
    paragraphs = retained.css('p').reject { |node| node.text.strip.empty? && node.css('img').length == 1 }
    expect(paragraphs.map(&:text)).to eq(
      [
        'This apparatus folds neatly inside its storage cabinet.',
        'Second independent field record',
        'A brief science update from the laboratory.'
      ]
    )
    expect(retained.css('img').map { |node| [node['src'], node['alt']] }).to eq(
      [
        ['https://publication.example.test/first.jpg', ''],
        ['https://publication.example.test/second.jpg', '']
      ]
    )
    expect(retained.css('a[href]').map { |node| [node.text.strip, node['href']] }).to eq(
      [
        ['', 'https://publication.example.test/records/first?mode=full#record'],
        ['First field record', 'https://publication.example.test/records/first?mode=full#record'],
        ['', "https://publication.example.test/records/#{second}?mode=full#record"],
        ['Second independent field record', "https://publication.example.test/records/#{second}?mode=full#record"]
      ]
    )
  end

  def owned_card_source_eligibility(page, options = {})
    directory = File.expand_path('../../../websieve', __dir__)
    files = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = files.map { |name| File.read(File.join(directory, name)) }.join("\n")
    raise 'ambiguous source namespace' unless source.scan('})(window);').length == 1

    probe = <<~JS
      global.ownedCardSourceEligibility = function(options) {
        var root = document.body.cloneNode(true);
        var sourceClones = new Map();
        function mapClone(source, clone) {
          sourceClones.set(source, clone);
          Array.from(source.childNodes).forEach(function(child, index) {
            mapClone(child, clone.childNodes[index]);
          });
        }
        mapClone(document.body, root);
        var heading = document.querySelector("h1");
        var identities = new WeakMap();
        identities.set(heading, { unique: options.unique !== false });
        var ownership = {
          node: document.querySelector(options.owner || "article"),
          heading: heading,
          titleIdentityProven: options.proven !== false
        };
        var result = readabilityOwnedCardCohorts(ownership, root, sourceClones, identities);
        return result ? result.cohorts.reduce(function(total, cohort) {
          return total + cohort.records.length;
        }, 0) : 0;
      };
      })(window);
    JS
    inject_standalone_extractor(page, reader_mode: true)
    page.add_script_tag(content: source.sub('})(window);', probe))
    page.evaluate("window.ownedCardSourceEligibility(#{JSON.generate(options)})")
  end

  it 'retains both physically owned card groups instead of choosing one inner text block' do
    with_owned_card_peers(owned_card_peer_source) do |payload, retained|
      expect_complete_owned_card_peers(retained)
      expect(payload.fetch('markdown')).to include(
        'First field record', 'Second independent field record',
        'https://publication.example.test/first.jpg', 'https://publication.example.test/second.jpg'
      )
    end
  end

  it 'keeps independent image and title occurrences when both records share one complete destination' do
    with_owned_card_peers(owned_card_peer_source(same_destination: true)) do |_payload, retained|
      expect_complete_owned_card_peers(retained, same_destination: true)
    end
  end

  it 'retains a complete literal program and its named HTTP binding beside the second peer' do
    program = "prepare('<sample>');\n\nfinish();"
    extra = "<pre id=\"program-target\"><code>#{CGI.escapeHTML(program)}</code></pre>" \
      '<p>Consult the <a href="https://reference.example.test/program?mode=full#target">complete program reference</a>.</p>'
    with_owned_card_peers(owned_card_peer_source(extra: extra)) do |payload, retained|
      expect(retained.css('pre').map(&:text)).to eq([program])
      expect(retained.at_css('pre#program-target')).not_to be_nil
      expect(retained.css('a[href]').last['href']).to eq('https://reference.example.test/program?mode=full#target')
      expect(payload.fetch('markdown')).to include(program, 'https://reference.example.test/program?mode=full#target')
    end
  end

  it 'keeps closed and source-hidden peer material out of the readable result' do
    extra = '<div hidden><a href="/private-hidden">HIDDEN_PEER_RESOURCE</a></div>' \
      '<details><summary>Deferred evidence</summary><p>CLOSED_PEER_BODY</p>' \
      '<a href="/private-closed"><img src="/private.jpg" alt="PRIVATE_PEER_IMAGE"></a></details>'
    with_owned_card_peers(owned_card_peer_source(extra: extra)) do |payload, retained|
      expect(retained.css('img').map { |node| node['src'] }).to include(
        'https://publication.example.test/first.jpg', 'https://publication.example.test/second.jpg'
      )
      expect(payload.fetch('markdown')).not_to include('HIDDEN_PEER_RESOURCE', 'CLOSED_PEER_BODY', 'PRIVATE_PEER_IMAGE')
      retained.css('a[href$="private-closed"]').each do |link|
        expect(link.ancestors('details:not([open])')).not_to be_empty
      end
    end
  end

  it 'preserves the same complete peer article when reader mode is disabled' do
    with_owned_card_peers(owned_card_peer_source, reader_mode: false) do |_payload, retained|
      expect_complete_owned_card_peers(retained)
    end
  end

  it 'does not borrow peer-shaped interface material from outside the source article' do
    html = <<~HTML
      <html><head><title>Independent narrative</title></head><body><main><article>
        <h1>Independent narrative</h1>
        <p>The first complete paragraph explains the authored narrative and keeps its independent source identity.</p>
        <p>The second complete paragraph continues the same publication without borrowing a navigation record.</p>
        <p>The final complete paragraph preserves the visible conclusions and the complete reporting context.</p>
      </article><nav>
        <div><a href="/unowned-one"><img src="/unowned-one.jpg" alt=""></a><a href="/unowned-one"><h3>UNOWNED_PEER_ONE</h3></a></div>
        <div><a href="/unowned-two"><img src="/unowned-two.jpg" alt=""></a><a href="/unowned-two"><p>UNOWNED_PEER_TWO</p></a></div>
      </nav></main></body></html>
    HTML
    with_owned_card_peers(html) do |payload, retained|
      expect(retained.css('p').length).to eq(3)
      expect(payload.fetch('markdown')).not_to include('UNOWNED_PEER', 'unowned-one', 'unowned-two')
    end
  end

  it 'requires complete physical peer ownership in the unminified source eligibility predicate' do
    [false, true].each do |same_destination|
      with_url_page('https://publication.example.test/research/', owned_card_peer_source(same_destination: same_destination)) do |page|
        before = page.evaluate('document.body.outerHTML')
        expect(owned_card_source_eligibility(page)).to eq(2)
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end

    cases = [
      ['one physical peer', ->(root) { root.css('.card').last.remove }, {}],
      ['different physical parents', lambda { |root|
        record = root.css('.card').last
        wrapper = Nokogiri::XML::Node.new('div', root.document)
        record.add_previous_sibling(wrapper)
        wrapper.add_child(record)
      }, {}],
      ['different image destination', lambda { |root|
        root.css('.card').last.at_css('a')['href'] = '/different-image?mode=full#record'
      }, {}],
      ['ambiguous title fields', lambda { |root|
        root.css('.card').last.css('a').last.add_child('<p>Another independent title</p>')
      }, {}],
      ['main is not an article', ->(root) { root.at_css('article').name = 'main' }, { owner: 'main main' }],
      ['source-hidden image', ->(root) { root.css('.card').last.at_css('img')['style'] = 'display:none' }, {}],
      ['interface-owned peer', ->(root) { root.css('.card').last['role'] = 'button' }, {}],
      ['unowned group prose', ->(root) { root.at_css('section').add_child('<p>Independent group prose</p>') }, {}],
      ['unproved publication identity', ->(_root) {}, { proven: false }],
      ['nonunique heading identity', ->(_root) {}, { unique: false }],
      ['heading outside its article', lambda { |root|
        root.at_css('article').add_previous_sibling(root.at_css('h1'))
      }, {}]
    ]
    cases.each do |name, mutate, options|
      source = Nokogiri::HTML5.parse(owned_card_peer_source)
      mutate.call(source)
      with_url_page('https://publication.example.test/research/', source.to_html) do |page|
        before = page.evaluate('document.body.outerHTML')
        expect(owned_card_source_eligibility(page, options)).to eq(0), name
        expect(page.evaluate('document.body.outerHTML')).to eq(before)
      end
    end
  end
end
