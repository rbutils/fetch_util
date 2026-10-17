# frozen_string_literal: true

require 'nokogiri'

RSpec.describe 'FetchUtil independently headed homepage ownership' do
  include_context 'extractor integration helpers'

  def peer_section_homepage
    sections = (1..35).map do |index|
      <<~HTML
        <section><div><h1>Independent feature #{index}</h1>
        <p>Feature #{index} explains a distinct public capability and the complete practical information that readers need.</p>
        <a href="/resources/#{index}">Complete resource #{index}</a></div></section>
      HTML
    end.join
    <<~HTML
      <html><head><title>Public media platform | Independent studio</title>
      <meta property="og:type" content="website"><meta property="og:title" content="Public media platform">
      <meta property="og:description" content="Complete public capabilities and independent resources."></head>
      <body><header><a href="/">Independent studio</a></header><main>#{sections}
      <section><h2>Published examples</h2><p>These examples remain part of the complete independently authored public page.</p>
      <pre><code>retain_complete_first_line();
      retain_complete_second_line();</code></pre></section></main><footer>Site navigation</footer></body></html>
    HTML
  end

  it 'retains every physical peer section and its complete HTML, Markdown and document identity' do
    with_url_page('https://platform.example.test/', peer_section_homepage) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload.fetch('title')).to eq('Public media platform')
      expect(payload.fetch('contentType')).to eq('list')
      expect(payload.values_at('byline', 'publishedTime', 'contentFormat')).to eq([nil, nil, nil])
      document = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(document.css('h1').length).to eq(35)
      expect(document.css('p').length).to eq(36)
      expect(document.css('a[href]').map { |node| node['href'] }).to eq((1..35).map { |index| "https://platform.example.test/resources/#{index}" })
      positions = (1..35).map do |index|
        expect(payload.fetch('markdown')).to include("https://platform.example.test/resources/#{index}",
                                                     "Feature #{index} explains a distinct public capability")
        payload.fetch('markdown').index("Independent feature #{index}")
      end
      expect(positions).to eq(positions.sort)
      expect(payload.fetch('markdown')).to include('retain_complete_first_line();', 'retain_complete_second_line();')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  def peer_homepage_context_probe
    directory = File.expand_path('../../../websieve', __dir__)
    script = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |line| File.read(File.join(directory, line)) }.join("\n")
    raise 'unexpected extraction boundary' unless script.scan('})(window);').length == 1

    script.sub('})(window);', <<~JS)
      global.peerHomepageProof = function() { return !!homepagePeerSectionsContext({title: document.title}); };
      })(window);
    JS
  end

  it 'declines foreign, ambiguous, article-owned and competing source owners and refreshes each proof' do
    with_url_page('https://platform.example.test/', peer_section_homepage) do |page|
      page.evaluate(peer_homepage_context_probe)
      body = page.evaluate('document.body.innerHTML')
      expect(page.evaluate('window.peerHomepageProof()')).to be(true)
      mutations = [
        "document.querySelector('meta[property=\"og:type\"]').content = 'article'",
        "document.title = 'A conflicting document identity'",
        "document.head.insertAdjacentHTML('beforeend', '<link rel=canonical href=https://foreign.example.test/>')",
        "document.body.insertAdjacentHTML('beforeend', '<main><h1>Competing owner</h1><p>Other content.</p></main>')",
        "document.body.insertAdjacentHTML('beforeend', '<p>Independent reporting outside the selected page owner must survive.</p>')",
        "document.body.insertAdjacentHTML('beforeend', '<iframe></iframe>')",
        "document.querySelector('main').insertAdjacentHTML('beforeend', '<article><h2>A focal article</h2><p>Separate reporting.</p></article>')",
        "document.querySelector('main').insertAdjacentHTML('beforeend', '<form><input name=account></form>')",
        "Array.from(document.querySelectorAll('main section > div > p')).forEach(function(node) { node.remove(); })"
      ]
      mutations.each do |mutation|
        page.evaluate(mutation)
        expect(page.evaluate('window.peerHomepageProof()')).to be(false), mutation
        page.evaluate('document.body.innerHTML = arguments[0]', body)
        page.evaluate("document.title = 'Public media platform | Independent studio'")
        page.evaluate("document.querySelector('meta[property=\"og:type\"]').content = 'website'")
        page.evaluate("document.querySelectorAll('link[rel=canonical]').forEach(function(node) { node.remove(); })")
        expect(page.evaluate('window.peerHomepageProof()')).to be(true), mutation
      end
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
      page.evaluate("document.body.insertAdjacentHTML('beforeend', '<iframe style=\"visibility:hidden;width:1px;height:1px\"></iframe>')")
      expect(page.evaluate('window.peerHomepageProof()')).to be(true)
      page.evaluate('document.body.innerHTML = arguments[0]', body)
    end
  end
end
