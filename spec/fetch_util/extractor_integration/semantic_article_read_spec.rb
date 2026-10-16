# frozen_string_literal: true

RSpec.describe 'Semantic article source reads' do
  include_context 'extractor integration helpers'

  def semantic_article_probe(page)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    probe = <<~JS
      global.semanticArticleProbe = function() {
        var metadata = { title: "Physical observations", siteName: "Publication" };
        var owner = document.querySelector("article");
        var original = computeElementOwnSubtreeHidden;
        var reads = 0;
        function view(result) {
          var owned = result.ownership;
          return { considered: result.considered, ownership: owned ? {
            title: owned.title, proven: owned.titleIdentityProven, proof: owned.proof,
            html: owned.body.visible.outerHTML, text: owned.body.text,
            paragraphs: owned.body.paragraphs,
            references: Array.from(owned.body.visible.querySelectorAll("a[href]")).map(function(link) {
              return [link.textContent, link.getAttribute("href")];
            })
          } : null };
        }
        computeElementOwnSubtreeHidden = function(node) {
          if (node === owner) reads += 1;
          return original.apply(this, arguments);
        };
        var before = document.body.innerHTML;
        try {
          var reference = view(computeSourceOwnedSemanticArticleOwnership(metadata));
          var uncached = reads;
          reads = 0;
          var actual = view(sourceOwnedSemanticArticleOwnership(metadata));
          return { reference: reference, actual: actual, uncached: uncached, cached: reads,
            unchanged: before === document.body.innerHTML, restored: sourceVisibilityReadContext === null };
        } finally { computeElementOwnSubtreeHidden = original; }
      };
      global.semanticArticleExceptionProbe = function() {
        return withSourceVisibilityRead(function() {
          var outer = sourceVisibilityReadContext;
          var original = sourceOwnedArticleHasUncoveredMaterial;
          sourceOwnedArticleHasUncoveredMaterial = function() { throw new Error("coverage interrupted"); };
          try {
            sourceOwnedSemanticArticleOwnership({ title: "Physical observations", siteName: "Publication" });
            return { raised: false, restored: false };
          } catch (error) {
            return { raised: error.message === "coverage interrupted", restored: sourceVisibilityReadContext === outer };
          } finally { sourceOwnedArticleHasUncoveredMaterial = original; }
        });
      };
    JS
    page.add_script_tag(content: source.sub('})(window);', "#{probe}\n})(window);"))
  end

  def physical_article_page(paragraphs, extra: '')
    <<~HTML
      <html><head><title>Physical observations</title></head><body><main>
      <article><h1>Physical observations</h1>#{paragraphs}#{extra}</article>
      </main></body></html>
    HTML
  end

  it 'retains all paragraphs and references while checking the shared physical ancestor once' do
    paragraphs = 603.times.map do |index|
      "<p>Observation #{index} describes independent measurements and the evidence needed to reproduce this result. " \
        "Readers can inspect <a href='/sources/#{index}'>source #{index}</a> and compare the complete methodology.</p>"
    end.join
    with_url_page('https://publication.example.test/reports/observations', physical_article_page(paragraphs)) do |page|
      semantic_article_probe(page)
      result = page.evaluate('semanticArticleProbe()')
      expect(result['actual']).to eq(result['reference'])
      expect(result.dig('actual', 'ownership', 'paragraphs')).to eq(603)
      expect(result['uncached']).to be > 603
      expect(result['cached']).to eq(1)
      expect(result.values_at('unchanged', 'restored')).to eq([true, true])
      references = result.dig('actual', 'ownership', 'references')
      expect(references).to eq(603.times.map { |index| ["source #{index}", "/sources/#{index}"] })
    end
  end

  it 'rechecks visibility and complete material after source changes' do
    paragraph = '<p>Independent observers recorded the complete measurements, methodology and supporting evidence for the public report.</p>'
    extra = '<p hidden id="later">A newly visible paragraph adds independent context and additional evidence to the same article.</p>'
    with_url_page('https://publication.example.test/reports/observations', physical_article_page(paragraph * 2, extra: extra)) do |page|
      semantic_article_probe(page)
      first = page.evaluate('semanticArticleProbe()')
      page.evaluate('document.getElementById("later").hidden = false')
      second = page.evaluate('semanticArticleProbe()')
      page.evaluate('document.querySelector("article").hidden = true')
      hidden = page.evaluate('semanticArticleProbe()')
      [first, second, hidden].each do |result|
        expect(result['actual']).to eq(result['reference'])
        expect(result.values_at('unchanged', 'restored')).to eq([true, true])
      end
      expect(first.dig('actual', 'ownership', 'paragraphs')).to eq(2)
      expect(second.dig('actual', 'ownership', 'paragraphs')).to eq(3)
      expect(hidden.dig('actual', 'ownership')).to be_nil
    end
  end

  it 'restores the enclosing read scope when article coverage raises' do
    paragraph = '<p>Independent observers recorded the complete measurements, methodology and supporting evidence for the public report.</p>'
    with_url_page('https://publication.example.test/reports/observations', physical_article_page(paragraph * 2)) do |page|
      semantic_article_probe(page)
      expect(page.evaluate('semanticArticleExceptionProbe()')).to eq('raised' => true, 'restored' => true)
      expect(page.evaluate('semanticArticleProbe()')['restored']).to be(true)
    end
  end
end
