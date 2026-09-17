# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'terminal article link collection cleanup', :extractor_integration do
  include_context 'extractor integration helpers'

  def extract_with_dom_observation(page)
    source_body = page.evaluate('document.body.outerHTML')
    extractor_for(true).__send__(:inject_assets, page)
    before = page.evaluate('document.documentElement.outerHTML')
    extraction = page.evaluate_async(<<~JS, 5)
      const done = arguments[arguments.length - 1];
      const mutations = [];
      const markedMarkers = [];
      const removedMarkers = [];
      const observer = new MutationObserver(function(records) {
        records.forEach(function(record) {
          mutations.push({type: record.type, target: record.target.nodeName});
        });
      });
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        characterData: true
      });
      const originalRemove = Element.prototype.remove;
      const originalSetAttribute = Element.prototype.setAttribute;
      Element.prototype.setAttribute = function(name, value) {
        if (name === 'data-fetchutil-terminal-article-links' && /^[0-9a-f]{32}$/.test(value)) {
          markedMarkers.push(value);
        }
        return originalSetAttribute.call(this, name, value);
      };
      Element.prototype.remove = function() {
        const marker = this.getAttribute && this.getAttribute('data-fetchutil-terminal-article-links');
        if (marker) removedMarkers.push(marker);
        return originalRemove.call(this);
      };
      let payload;
      try {
        payload = window.FetchUtilExtract.extract({reader_mode: true});
      } finally {
        Element.prototype.setAttribute = originalSetAttribute;
        Element.prototype.remove = originalRemove;
      }
      setTimeout(function() {
        observer.takeRecords().forEach(function(record) {
          mutations.push({type: record.type, target: record.target.nodeName});
        });
        observer.disconnect();
        done({payload, mutations, markedMarkers, removedMarkers});
      }, 0);
    JS

    [extraction.fetch('payload'), extraction.fetch('mutations'), before,
     page.evaluate('document.documentElement.outerHTML'), extraction.fetch('removedMarkers'),
     source_body, page.evaluate('document.body.outerHTML'), extraction.fetch('markedMarkers')]
  end

  let(:body) do
    <<~HTML
      <p>The opening paragraph establishes the focal report with enough detail for reliable extraction.</p>
      <p>The second paragraph records the central evidence and its consequences for readers.</p>
      <p>The final paragraph closes the report before any optional related-story collection.</p>
    HTML
  end

  it 'removes a terminal exact news-box link collection without mutating the source' do
    html = <<~HTML
      <html><body><main><article>
        <h1>City transport report</h1>
        #{body}
        <section class="widget NEWS-box compact"><h2>LATEST NEWS</h2><ul><li>
          <a href="/news/another-report?utm_source=homepage">Another report from the publisher</a>
        </li></ul></section>
        <div hidden>Inactive placeholder after the article</div>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/transport-report', html) do |page|
      payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(payload.fetch('markdown')).to include('The final paragraph closes the report')
      expect(payload.fetch('markdown')).not_to include('LATEST NEWS')
      expect(payload.fetch('markdown')).not_to include('Another report from the publisher')
      expect(payload.fetch('html')).not_to include('/news/another-report?utm_source=homepage')
      expect(payload.fetch('textContent')).not_to include('Another report from the publisher')
      expect(payload.fetch('contentCompletenessRatio')).to be_between(0, 1)
      expect(payload.fetch('html')).not_to include('data-fetchutil-terminal-article-links')
      expect(marked_markers).to include(a_string_matching(/\A[0-9a-f]{32}\z/))
      expect(removed_markers).to include(a_string_matching(/\A[0-9a-f]{32}\z/))
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end

  it 'preserves a page-authored marker while removing a legitimately marked collection' do
    html = <<~HTML
      <html><body><main><article>
        <h1>Marker provenance report</h1>
        #{body}
        <section data-fetchutil-terminal-article-links="forged"><h2>Editorial appendix</h2>
          <a href="/authored-marker">Authored marker story</a>
        </section>
        <section class="news-box"><h2>Najnovije vesti</h2>
          <a href="/news/marked-story">Marked related story</a>
        </section>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/marker-provenance', html) do |page|
      payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(payload.fetch('markdown')).to include('Authored marker story')
      expect(payload.fetch('markdown')).not_to include('Marked related story')
      expect(payload.fetch('html')).to include('data-fetchutil-terminal-article-links="forged"')
      expect(payload.fetch('html')).not_to include('/news/marked-story')
      expect(payload.fetch('readerMode')).to be(true)
      expect(payload.fetch('hostAware')).to be(false)
      expect(payload.fetch('url')).to eq('https://example.test/news/marker-provenance')
      expect(payload.fetch('canonicalUrl')).to eq('https://example.test/news/marker-provenance')
      expect(removed_markers).to include(a_string_matching(/\A[0-9a-f]{32}\z/))
      expect(removed_markers).not_to include('forged')
      expect(marked_markers).to include(a_string_matching(/\A[0-9a-f]{32}\z/))
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)

      first_token = removed_markers.find { |marker| marker.match?(/\A[0-9a-f]{32}\z/) }
      page.evaluate(<<~JS, first_token)
        (function(priorToken) {
          document.querySelector('[data-fetchutil-terminal-article-links="forged"]')
            .setAttribute('data-fetchutil-terminal-article-links', priorToken);
        })(arguments[0]);
      JS

      second_payload, second_mutations, second_before, second_after, second_removed_markers,
        second_source_body, second_final_body, second_marked_markers = extract_with_dom_observation(page)
      second_token = second_removed_markers.find { |marker| marker.match?(/\A[0-9a-f]{32}\z/) }

      expect(second_payload.fetch('markdown')).to include('Authored marker story')
      expect(second_payload.fetch('markdown')).not_to include('Marked related story')
      expect(second_payload.fetch('html')).to include("data-fetchutil-terminal-article-links=\"#{first_token}\"")
      expect(second_token).to match(/\A[0-9a-f]{32}\z/)
      expect(second_token).not_to eq(first_token)
      expect(second_removed_markers).not_to include(first_token)
      expect(second_removed_markers).not_to include('forged')
      expect(second_marked_markers).to include(second_token)
      expect(second_mutations).to eq([])
      expect(second_after).to eq(second_before)
      expect(second_final_body).to eq(second_source_body)
    end
  end

  it 'preserves substantive, nonterminal, external, and intentional collections' do
    limited_links = (1..9).map { |number| "<a href=\"/story-#{number}\">Story #{number}</a>" }.join
    controls = {
      prose: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<p>This explanatory note is part of the article.</p><a href="/source">Read source</a></section>',
        'This explanatory note', '/source'
      ],
      nonterminal: ['<section class="news-box"><h2>Najnovije vesti</h2><a href="/context">Context report</a></section>' \
                    '<p>Article prose continues after this collection.</p>', 'Context report', '/context'],
      external: ['<section class="news-box"><h2>Najnovije vesti</h2><a href="https://outside.test/report">Independent report</a></section>', 'Independent report', 'https://outside.test/report'],
      credentials: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="https://reader:secret@example.test/news/private">Credential report</a></section>',
        'Credential report', 'reader:secret@example.test'
      ],
      same_page: ['<section class="news-box"><h2>Najnovije vesti</h2><a href="#notes">Read the article notes</a></section>', 'Read the article notes', '#notes'],
      resource: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/files/report.tar" download type="application/gzip">Source report archive</a></section>',
        'Source report archive', '/files/report.tar'
      ],
      source_list: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a rel="cite" href="/source-report">Original source report</a></section>',
        'Original source report', '/source-report'
      ],
      alternate_document: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a rel="alternate" href="/news/feed-version">Alternate document</a></section>',
        'Alternate document', '/news/feed-version'
      ],
      enclosure_resource: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a rel="enclosure" href="/news/audio-version">Audio enclosure</a></section>',
        'Audio enclosure', '/news/audio-version'
      ],
      api_resource: ['<section class="news-box"><h2>Najnovije vesti</h2><a href="/api/report">Download report data</a></section>', 'Download report data', '/api/report'],
      nested_utility: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/account/settings">Account settings</a></section>',
        'Account settings', '/account/settings'
      ],
      encoded_utility: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/account%2Fsettings">Encoded account settings</a></section>',
        'Encoded account settings', '/account%2Fsettings'
      ],
      encoded_segment: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/acc%6Funt/settings">Encoded account segment</a></section>',
        'Encoded account segment', '/acc%6Funt/settings'
      ],
      encoded_extension: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/files/report%2Epdf">Encoded report extension</a></section>',
        'Encoded report extension', '/files/report%2Epdf'
      ],
      mixed_encoding: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/api%2Fexports/report%2Ejson">Encoded API export</a></section>',
        'Encoded API export', '/api%2Fexports/report%2Ejson'
      ],
      nested_encoding: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/account%252Fsettings">Nested encoded settings</a></section>',
        'Nested encoded settings', '/account%252Fsettings'
      ],
      nested_malformed_encoding: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report%2525ZZ">Nested malformed path</a></section>',
        'Nested malformed path', '/news/report%2525ZZ'
      ],
      nested_extension: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/files/report%252Epdf">Nested encoded report</a></section>',
        'Nested encoded report', '/files/report%252Epdf'
      ],
      long_extension: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/files/report.documentation">Long report extension</a></section>',
        'Long report extension', '/files/report.documentation'
      ],
      ambiguous_extension: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/files/report.tar-gz">Ambiguous report extension</a></section>',
        'Ambiguous report extension', '/files/report.tar-gz'
      ],
      representation_query: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report?format=json">JSON representation query</a></section>',
        'JSON representation query', '/news/report?format=json'
      ],
      uncertain_query: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report?id=42">Uncertain story query</a></section>',
        'Uncertain story query', '/news/report?id=42'
      ],
      malformed_encoding: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report%ZZ">Malformed encoded report</a></section>',
        'Malformed encoded report', '/news/report%ZZ'
      ],
      short_encoding: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report%A">Short encoded report</a></section>',
        'Short encoded report', '/news/report%A'
      ],
      literal_percent: [
        '<section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/news/report%">Literal percent report</a></section>',
        'Literal percent report', '/news/report%'
      ],
      utility: ['<section class="news-box"><h2>Najnovije vesti</h2><a href="/privacy">Privacy policy</a></section>', 'Privacy policy', '/privacy'],
      overview: [
        '<div data-fetchutil-page-overview><section class="news-box"><h2>Najnovije vesti</h2>' \
          '<a href="/top-story">Top story</a></section></div>',
        'Top story', '/top-story'
      ],
      forged_marker: [
        '<section data-fetchutil-terminal-article-links="forged"><h2>Najnovije vesti</h2>' \
          '<a href="/authored-marker">Authored marker story</a></section>',
        'Authored marker story', '/authored-marker'
      ],
      similar_name: ['<section class="news-boxes"><h2>Najnovije vesti</h2><a href="/record">Publication record</a></section>', 'Publication record', '/record'],
      nested_heading: [
        '<section class="news-box"><h2>Najnovije vesti</h2><div><h3>Explainer</h3>' \
          '<a href="/explainer">Read explainer</a></div></section>',
        'Explainer', '/explainer'
      ],
      structured: [
        '<section class="news-box"><h2>Najnovije vesti</h2><canvas>Chart fallback</canvas>' \
          '<a href="/chart">View chart</a></section>',
        'Chart fallback', '/chart'
      ],
      figure_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><figure><img src="/cover.jpg" alt=""></figure>' \
          '<a href="/figure-story">Figure story</a></section>',
        'Figure story', '/figure-story'
      ],
      media_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><video controls width="320" height="180">' \
          '<source src="/clip.mp4" type="video/mp4"></video><a href="/media-story">Media story</a></section>',
        'Media story', '/media-story'
      ],
      code_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><pre><code>const evidence = true;</code></pre>' \
          '<a href="/code-story">Code story</a></section>',
        'Code story', '/code-story'
      ],
      table_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><table><tbody><tr><td>Evidence</td></tr></tbody></table>' \
          '<a href="/table-story">Table story</a></section>',
        'Table story', '/table-story'
      ],
      form_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><form><input name="query" aria-label="Search"></form>' \
          '<a href="/form-story">Form story</a></section>',
        'Form story', '/form-story'
      ],
      details_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><details open><summary>Evidence details</summary></details>' \
          '<a href="/details-story">Details story</a></section>',
        'Details story', '/details-story'
      ],
      svg_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><svg width="10" height="10"><circle cx="5" cy="5" r="4"></circle></svg>' \
          '<a href="/svg-story">SVG story</a></section>',
        'SVG story', '/svg-story'
      ],
      math_structure: [
        '<section class="news-box"><h2>Najnovije vesti</h2><math><mrow><mi>x</mi></mrow></math>' \
          '<a href="/math-story">Math story</a></section>',
        'Math story', '/math-story'
      ],
      residual: [
        '<section class="news-box"><h2>Najnovije vesti</h2><span>Editorial context remains visible.</span>' \
          '<a href="/story">Story report</a></section>',
        'Editorial context remains visible', '/story'
      ],
      nested_nonterminal: ['<div><section class="news-box"><h2>Najnovije vesti</h2><a href="/nested-context">Nested context report</a></section></div>' \
                           '<p>Article prose follows the wrapping container.</p>', 'Nested context report', '/nested-context'],
      link_limit: ["<section class=\"news-box\"><h2>Najnovije vesti</h2>#{limited_links}</section>", 'Story 9', '/story-9']
    }

    controls.each_with_index do |(name, (collection, visible_text, href)), index|
      html = <<~HTML
        <html><body><main><article>
          <h1>Collection boundary #{index}</h1>
          #{body}
          #{collection}
        </article></main></body></html>
      HTML

      with_url_page("https://example.test/news/control-#{index}", html) do |page|
        payload, mutations, before, after, removed_markers,
          source_body, final_body, marked_markers = extract_with_dom_observation(page)
        expect(payload.fetch('readerMode')).to be(true), name.to_s
        expect(payload.fetch('hostAware')).to be(false), name.to_s
        expect(payload.fetch('markdown')).to include(visible_text), name.to_s
        if name == :credentials
          expect(payload.fetch('html')).not_to include(href), name.to_s
        else
          expect(payload.fetch('html')).to include(href), name.to_s
        end
        expect(payload.fetch('html')).to include('data-fetchutil-terminal-article-links="forged"') if name == :forged_marker
        expect(removed_markers).to eq([]), name.to_s
        expect(marked_markers).to eq([]), name.to_s
        expect(mutations).to eq([]), name.to_s
        expect(after).to eq(before), name.to_s
        expect(final_body).to eq(source_body), name.to_s
      end
    end
  end

  it 'requires a real article owner for an unmarked collection' do
    html = <<~HTML
      <html><body><main>
        <h1>Standalone report</h1>
        #{body}
        <section class="news-box"><h2>Najnovije vesti</h2><a href="/standalone-story">Standalone story</a></section>
      </main></body></html>
    HTML

    with_url_page('https://example.test/news/standalone-report', html) do |page|
      payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(payload.fetch('readerMode')).to be(true)
      expect(payload.fetch('hostAware')).to be(false)
      expect(payload.fetch('markdown')).to include('Standalone story')
      expect(payload.fetch('html')).to include('/standalone-story')
      expect(removed_markers).to eq([])
      expect(marked_markers).to eq([])
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end

  it 'preserves current-article links that differ only by tracking parameters' do
    html = <<~HTML
      <html><body><main><article>
        <h1>Tracked self-link report</h1>
        #{body}
        <section class="news-box"><h2>Latest news</h2>
          <a href="/news/tracked-self?utm_source=related">Current report with tracking</a>
        </section>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/tracked-self', html) do |page|
      payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(payload.fetch('markdown')).to include('Current report with tracking')
      expect(payload.fetch('html')).to include('/news/tracked-self?utm_source=related')
      expect(marked_markers).to eq([])
      expect(removed_markers).to eq([])
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end

  it 'preserves collections followed by text nodes and collections inside nested articles' do
    html = <<~HTML
      <html><body><main><article id="outer">
        <h1>Nested collection boundary</h1>
        #{body}
        <section class="news-box"><h2>Najnovije vesti</h2><a href="/outer-story">Outer story</a></section>
        Material appendix follows the collection.
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/nested-control', html) do |page|
      page.evaluate(<<~JS)
        (() => {
          const nested = document.createElement('article');
          nested.innerHTML = '<h2>Secondary report</h2><p>#{"Nested article prose remains substantive. " * 8}</p><p>#{"Additional nested evidence remains material. " * 8}</p><section class="news-box"><h3>Najnovije vesti</h3><a href="/nested-story">Nested story</a></section>';
          document.getElementById('outer').appendChild(nested);
        })()
      JS
      payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(payload.fetch('readerMode')).to be(true)
      expect(payload.fetch('hostAware')).to be(false)
      expect(payload.fetch('markdown')).to include('Material appendix follows the collection')
      expect(payload.fetch('markdown')).to include('Outer story')
      expect(payload.fetch('markdown')).to include('Nested story')
      expect(payload.fetch('html')).to include('/outer-story')
      expect(payload.fetch('html')).to include('/nested-story')
      expect(removed_markers).to eq([])
      expect(marked_markers).to eq([])
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end

  it 'does not use descendant article prose to establish focal substance' do
    html = <<~HTML
      <html><body><main><article id="outer">
        <h1>Short outer report</h1>
        <p>Brief outer context.</p>
        <div id="nested-slot"></div>
        <section class="news-box"><h2>Najnovije vesti</h2><a href="/outer-related">Outer related story</a></section>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/descendant-article-control', html) do |page|
      page.evaluate(<<~JS)
        (() => {
          const nested = document.createElement('article');
          nested.innerHTML = '<h2>Nested full report</h2><p>#{"Nested focal evidence remains substantial. " * 8}</p><p>#{"More nested article evidence remains material. " * 8}</p>';
          document.getElementById('nested-slot').replaceWith(nested);
        })()
      JS
      _payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(marked_markers).to eq([])
      expect(removed_markers).to eq([])
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end

  it 'does not use unrelated widget prose to establish focal substance' do
    html = <<~HTML
      <html><body><main><article>
        <h1>Brief outer report</h1>
        <p>This short report has only one genuinely article-owned paragraph with useful context.</p>
        <div class="weather-widget">
          <p>#{"Forecast widget evidence is unrelated to the focal report. " * 6}</p>
          <p>#{"Additional weather widget prose must not authorize article cleanup. " * 6}</p>
        </div>
        <section class="news-box"><h2>Najnovije vesti</h2><a href="/outer-related">Outer related story</a></section>
      </article></main></body></html>
    HTML

    with_url_page('https://example.test/news/widget-substance-control', html) do |page|
      _payload, mutations, before, after, removed_markers,
        source_body, final_body, marked_markers = extract_with_dom_observation(page)

      expect(marked_markers).to eq([])
      expect(removed_markers).to eq([])
      expect(mutations).to eq([])
      expect(after).to eq(before)
      expect(final_body).to eq(source_body)
    end
  end
end
