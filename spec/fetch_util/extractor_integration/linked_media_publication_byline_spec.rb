# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil linked media publication credit ownership' do
  include_context 'extractor integration helpers'

  def linked_cover_probe_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    marker = '})(window);'
    raise 'ambiguous cover probe boundary' unless source.scan(marker).length == 1
    source.sub(marker, <<~JAVASCRIPT)
      global.probeLinkedCoverCredit = function() {
        var before = document.body.innerHTML;
        var credit = document.getElementById('credit');
        return {
          articleByline: articleBylineNode(credit), byline: visibleByline(),
          credit: credit.textContent,
          references: Array.from(document.querySelectorAll('a[href]'), function(link) { return [link.textContent, link.href]; }),
          image: Array.from(document.querySelectorAll('img'), function(image) { return [image.getAttribute('alt'), image.src]; }),
          program: document.querySelector('pre').textContent,
          unchanged: before === document.body.innerHTML
        };
      };
      })(window);
    JAVASCRIPT
  end

  def linked_cover_html(destination: '/issues/issue-307/', title: 'Issue 307', extra_heading: '', link_attributes: '')
    <<~HTML
      <!doctype html><html><head><title>Publication catalogue</title>
        <link rel="canonical" href="https://publication.example.test/catalogue/">
      </head><body><main><h1>Publication catalogue</h1>
        <section id="publication"><div class="cover-column">
          <a #{link_attributes} href="#{destination}"><img src="/assets/cover-307.jpg" alt="Publication number 307"></a>
          <span id="credit" class="author">Cover | Ari Lens</span>
          <button><a href="/issues/">All publications</a></button>
        </div><div class="contents-column"><h1>#{title}</h1>#{extra_heading}
          <h2><a href="/reports/river/">Independent river report</a></h2>
          <p>The complete introductory paragraph belongs to this separately linked publication.</p>
          <h2><a href="/reports/forest/">Independent forest report</a></h2>
          <p>The complete second paragraph and both source references remain material.</p>
        </div></section><pre>first_code()

      last_code()</pre>
      </main></body></html>
    HTML
  end

  def cover_probe(html)
    with_url_page('https://publication.example.test/catalogue/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: linked_cover_probe_source)
      value = page.evaluate('probeLinkedCoverCredit()')
      expect(value.fetch('credit')).to eq('Cover | Ari Lens')
      expect(value.fetch('program')).to eq("first_code()\n\nlast_code()")
      expect(value.fetch('references').map(&:first)).to eq(['', 'All publications', 'Independent river report', 'Independent forest report'])
      expect(value.fetch('image')).to eq([['Publication number 307', 'https://publication.example.test/assets/cover-307.jpg']])
      expect(value.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield(value)
    end
  end

  it 'keeps a separately identified linked publication cover credit out of the catalogue byline' do
    cover_probe(linked_cover_html) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([false, nil])
      expect(value.fetch('references').first.last).to eq('https://publication.example.test/issues/issue-307/')
    end
  end

  it 'preserves a genuine person-profile credit beside an image' do
    cover_probe(linked_cover_html(destination: '/authors/ari-lens/')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'does not make an uncorroborated linked image a publication owner' do
    cover_probe(linked_cover_html(destination: '/photographs/unidentified-image/')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'preserves a current-document query link beside its own heading' do
    cover_probe(linked_cover_html(destination: '/catalogue/?utm_source=cover', title: 'Publication catalogue')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'does not treat an image-file destination as a separately titled publication' do
    cover_probe(linked_cover_html(destination: '/assets/issue-307.jpg')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'retains an attribution when equal principal headings make media ownership ambiguous' do
    cover_probe(linked_cover_html(extra_heading: '<h1>Another independent publication</h1>')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'does not use a hidden media link as a publication ownership witness' do
    cover_probe(linked_cover_html(link_attributes: 'style="display:none"')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'retains the current publication attribution when its document title has a publisher suffix' do
    html = linked_cover_html(destination: '/features/publication-catalogue/', title: 'Publication catalogue')
           .sub('<title>Publication catalogue</title>', '<title>Publication catalogue | Independent Publisher</title>')
    cover_probe(html) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'retains the current publication attribution when its document title has a publisher prefix' do
    html = linked_cover_html(destination: '/features/publication-catalogue/', title: 'Publication catalogue')
           .sub('<title>Publication catalogue</title>', '<title>Independent Publisher | Publication catalogue</title>')
    cover_probe(html) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  def repeated_cover_html(second_title: 'Publication', second_destination: '/issues/special-supplement/',
                          first_attributes: '', credit_wrapper: false, article_owner: false)
    first = linked_cover_html.sub('id="credit"', 'id="primary-credit"')
                             .sub('<section id="publication">', "<section id=\"publication\" #{first_attributes}>")
    second = linked_cover_html(destination: second_destination, title: second_title)
             .match(%r{<section id="publication">.*?</section>}m)[0]
             .sub('id="publication"', 'id="independent-publication"')
             .sub('/assets/cover-307.jpg', '/assets/supplement.jpg')
    if credit_wrapper
      second = second.sub('<span id="credit" class="author">Cover | Ari Lens</span>',
                          '<div><span id="credit" class="author">Cover | Ari Lens</span></div>')
    end
    second = "<article>#{second}</article>" if article_owner
    first.sub('</main>', "#{second}</main>")
  end

  def repeated_cover_probe(html)
    with_url_page('https://publication.example.test/catalogue/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: linked_cover_probe_source)
      value = page.evaluate('probeLinkedCoverCredit()')
      expect(value.fetch('credit')).to eq('Cover | Ari Lens')
      expect(value.fetch('program')).to eq("first_code()\n\nlast_code()")
      expect(value.fetch('references').map(&:first)).to eq(Array.new(2, ['', 'All publications', 'Independent river report', 'Independent forest report']).flatten)
      expect(value.fetch('image')).to eq(
        [
          ['Publication number 307', 'https://publication.example.test/assets/cover-307.jpg'],
          ['Publication number 307', 'https://publication.example.test/assets/supplement.jpg']
        ]
      )
      expect(value.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      yield(value)
    end
  end

  it 'recognizes the corresponding media credit in another complete physical publication record' do
    repeated_cover_probe(repeated_cover_html) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([false, nil])
    end
  end

  it 'does not transfer publication ownership across different physical credit fields' do
    repeated_cover_probe(repeated_cover_html(credit_wrapper: true)) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'does not transfer publication ownership between unrelated destination collections' do
    repeated_cover_probe(repeated_cover_html(second_destination: '/photographs/unidentified-image/')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'does not use a hidden source record to classify another visible credit' do
    repeated_cover_probe(repeated_cover_html(first_attributes: 'style="display:none"')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'preserves the corresponding current-document attribution' do
    repeated_cover_probe(repeated_cover_html(second_title: 'Publication catalogue')) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end

  it 'preserves an explicitly article-owned attribution despite a similar external record' do
    repeated_cover_probe(repeated_cover_html(article_owner: true)) do |value|
      expect(value.values_at('articleByline', 'byline')).to eq([true, 'Cover | Ari Lens'])
    end
  end
end
