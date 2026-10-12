# frozen_string_literal: true

RSpec.describe 'FetchUtil unselected collection lifetime' do
  include_context 'extractor integration helpers'

  def collection_lifetime_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    source.sub('})(window);', <<~JAVASCRIPT)
      global.checkCollectionLifetime = function() {
        var before = document.body.innerHTML;
        var originalBuild = buildListExtraction;
        var candidates = contextualListCandidates;
        var roots = [];
        contextualListCandidates = function() { return Array.from(document.querySelectorAll(".collection")); };
        buildListExtraction = function() {
          var result = originalBuild.apply(this, arguments);
          roots.push(result.root);
          return result;
        };
        function previous(metadata, pageTitles, options) {
          var nodes = [];
          function push(node) { if (node && nodes.indexOf(node) === -1) nodes.push(node); }
          push(listCandidateRoot(metadata));
          contextualListCandidates(metadata).forEach(push);
          push(document.querySelector("main, [role='main']"));
          push(document.body);
          var extractions = [];
          var best = nodes.reduce(function(current, node) {
            var result = buildListExtraction(node, pageTitles, options);
            extractions.push(result);
            return nestedListMaterialCoverage(current, result) || (listExtractionIsBetter(current, result) ? result : current);
          }, null);
          var ancestor = extractions.find(function(result) {
            return result !== best && result.descText && result.sourceNode.contains(best.sourceNode);
          });
          if (ancestor) { best.ancestorDescription = ancestor.descText; best.ancestorDescriptionSourceNode = ancestor.sourceNode; }
          return best;
        }
        function snapshot(result) {
          return {
            html: result.root.innerHTML, markdown: result.markdown, score: result.score,
            ancestorDescription: result.ancestorDescription || null,
            cards: result.items.map(function(item) {
              return { text: item.text, url: item.url, html: item.card ? item.card.outerHTML : null };
            })
          };
        }
        var result;
        try {
          var metadata = {title: document.title};
          var baseline = snapshot(withSourceVisibilityRead(function() { return previous(metadata, [document.title], {}); }));
          roots = [];
          var selected = bestListExtraction(metadata, [document.title], {});
          result = {
            baseline: baseline, selected: snapshot(selected),
            candidates: roots.length,
            discardedDescendants: roots.filter(function(root) { return root !== selected.root; }).reduce(function(count, root) {
              return count + root.querySelectorAll("*").length;
            }, 0),
            sourceUnchanged: before === document.body.innerHTML
          };
        } finally { buildListExtraction = originalBuild; contextualListCandidates = candidates; }
        return result;
      };
      global.checkBorrowedCollectionNodes = function() {
        var source = document.querySelector("main");
        var selected = source.cloneNode(true);
        var borrowed = source.cloneNode(true);
        var discarded = source.cloneNode(true);
        retireUnselectedListRoots([
          {root: selected, sourceNode: source}, {root: borrowed, sourceNode: source},
          {root: discarded, sourceNode: source}, {root: source, sourceNode: source}
        ], {root: selected, items: [{card: borrowed.querySelector("p")}]});
        return [selected.textContent, borrowed.textContent, discarded.childNodes.length, source.textContent];
      };
      })(window);
    JAVASCRIPT
  end

  it 'keeps complete selected records and ancestor descriptions while releasing every unselected disposable tree' do
    groups = 12.times.map do |group|
      records = 20.times.map do |record|
        number = group * 20 + record
        "<article><h3><a href='/record/#{number}'>Published record #{number}</a></h3>" \
          "<p>Complete authored explanation for published record #{number}.</p></article>"
      end.join
      "<section class='collection'><h2>Published section #{group}</h2>#{records}</section>"
    end.join
    html = "<title>Published records</title><main><p>Complete introduction describes the published collection.</p>#{groups}</main>"
    with_url_page('https://publication.example.test/', html) do |page|
      previous_timeout = page.timeout
      page.timeout = 120
      page.add_script_tag(content: collection_lifetime_source)
      result = page.evaluate('checkCollectionLifetime()')
      expect(result.fetch('selected')).to eq(result.fetch('baseline'))
      expect(result.fetch('candidates')).to be >= 12
      expect(result.fetch('discardedDescendants')).to eq(0)
      expect(result.fetch('sourceUnchanged')).to be(true)
      240.times do |number|
        expect(result.fetch('selected').fetch('markdown')).to include("Published record #{number}", "record/#{number}")
      end
    ensure
      page.timeout = previous_timeout
    end
  end

  it 'preserves borrowed selected cards and connected physical source nodes' do
    with_url_page('https://publication.example.test/', '<main><p>Complete published paragraph.</p></main>') do |page|
      page.add_script_tag(content: collection_lifetime_source)
      expected = ['Complete published paragraph.', 'Complete published paragraph.', 0, 'Complete published paragraph.']
      expect(page.evaluate('checkBorrowedCollectionNodes()')).to eq(expected)
    end
  end
end
