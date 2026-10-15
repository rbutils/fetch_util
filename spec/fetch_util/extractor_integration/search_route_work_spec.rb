# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Search classification eligibility' do
  include_context 'extractor integration helpers'

  def search_route_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.searchRouteProbe = function(content) {
        var original = articleRouteFocalContent, reads = 0;
        articleRouteFocalContent = function() {
          reads++;
          return original.apply(null, arguments);
        };
        try {
          var search = searchResultsListPage(content, '');
          var searchReads = reads;
          var thin = thinSearchOrCategoryPage(content);
          return {search: search, thin: thin, searchReads: searchReads, thinReads: reads - searchReads};
        } finally {
          articleRouteFocalContent = original;
        }
      };
      })(window);
    JS
  end

  it 'does no focal reconstruction for complete material on ineligible routes' do
    sections = (1..240).map do |number|
      "<section><h2>Technical section #{number}</h2><p>Complete published explanation #{number} remains visible.</p>" \
        "<a href='/record/#{number}'>Source reference #{number}</a><pre><code>value_#{number} = #{number};</code></pre></section>"
    end.join
    html = "<title>Engine reference guide</title><article role='main'><h1>Engine reference guide</h1>#{sections}</article>"
    with_url_page('https://publication.example.test/docs/engine-reference.html', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: search_route_probe)
      result = page.evaluate(<<~JS)
        searchRouteProbe({contentType: 'article', title: document.title, html: document.body.innerHTML})
      JS
      expect(result).to eq('search' => false, 'thin' => false, 'searchReads' => 0, 'thinReads' => 0)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(page.evaluate('document.querySelectorAll("section, pre, a[href]").length')).to eq(720)
    end
  end

  it 'retains eligible search cards and complete classification evidence' do
    cards = (1..3).map do |number|
      "<section class='result'><h2><a href='/document/record-#{number}'>Published source record #{number}</a></h2>" \
        "<p>Complete description #{number}.</p></section>"
    end.join
    html = <<~HTML
      <title>Search Results</title>
      <main>
        <h1>Search Results</h1>
        <p>Results 1 - 3 of 3</p>
        #{cards}
      </main>
    HTML
    with_url_page('https://records.example.test/search.html?text=sample', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: search_route_probe)
      result = page.evaluate(<<~JS)
        searchRouteProbe({contentType: 'article', title: document.title, html: document.body.innerHTML})
      JS
      expect(result).to eq('search' => true, 'thin' => true, 'searchReads' => 1, 'thinReads' => 1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps actual focal reporting ahead of a search-route classification' do
    paragraphs = (1..5).map do |number|
      "<p>Published reporting paragraph #{number} explains the complete evidence, attribution and source relationships. " \
        'This authored article remains a coherent primary report rather than a collection of result cards.</p>'
    end.join
    html = "<title>Published investigation</title><main><article role='main'><h1>Published investigation</h1>#{paragraphs}</article></main>"
    with_url_page('https://publication.example.test/search?q=evidence', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: search_route_probe)
      result = page.evaluate(<<~JS)
        searchRouteProbe({contentType: 'article', title: document.title, html: document.body.innerHTML})
      JS
      expect(result).to eq('search' => false, 'thin' => false, 'searchReads' => 1, 'thinReads' => 1)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
