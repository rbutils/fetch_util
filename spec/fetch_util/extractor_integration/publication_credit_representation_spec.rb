# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Physical publication credit representation' do
  include_context 'extractor integration helpers'

  def publication_credit_probe
    directory = File.expand_path('../../../websieve', __dir__)
    source = File.readlines(File.join(directory, 'manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |file| File.read(File.join(directory, file)) }.join("\n")
    source.sub('})(window);', <<~JS)
      window.publicationCreditProbe = function(mode) {
        return withInertDomWork(function() {
          return withComposedDomRead(function() {
            var root = document.querySelector('main'), before = root.outerHTML;
            var card = root.querySelector('section'), link = card.querySelector('h2 a');
             var item = {text: link.textContent, url: link.href, card: card, sourceNode: link};
             if (mode === 'fallback') item.author = root.querySelector('.fallback-credit').textContent;
            var category = card.querySelector('.category');
            if (category) item.category = category.textContent;
            if (mode === 'group') item.groupLabel = card.querySelector('h1').textContent;
            var parts = listPublicationCreditDescriptionParts(root, [item], []);
            return {parts: parts.map(function(part) { return part.markdown; }),
              markdown: listMarkdown([item]), unchanged: root.outerHTML === before,
              sourceCredits: Array.from(root.querySelectorAll('.publication-author')).map(function(node) {
                return {text: node.textContent, html: node.outerHTML};
              })};
          })({});
        })({});
      };
      })(window);
    JS
  end

  def publication_credit_source(mode)
    credit = mode == 'rich' ? '<strong>Cover | Ari Lens</strong>' : 'Cover | Ari Lens'
    attributes = case mode
                 when 'named' then 'id="credit-target"'
                 when 'hidden' then 'style="display:none"'
                 when 'fallback' then 'content=" "'
                 else ''
                 end
    duplicate = mode == 'independent' ? '<span class="publication-author">Cover | Ari Lens</span>' : ''
    category = mode == 'collision' ? '<span class="category">Cover | Ari Lens</span>' : ''
    fallback = mode == 'fallback' ? '<p class="fallback-credit">Cover | Ari Lens</p>' : ''
    <<~HTML
      <title>Publication catalogue</title><main><h1>Publication catalogue</h1>
      <section class="publication-record"><div class="cover-column">
        <a href="/issues/issue-307/"><img src="/covers/307.png" alt="Publication number 307"></a>
        <span class="publication-author" #{attributes}>#{credit}</span>#{duplicate}
      </div><div class="contents-column"><h1>Issue 307</h1>#{category}
        <h2><a href="/issues/issue-307/river/?edition=2&amp;view=full#details">River report 307</a></h2>
        <p>Complete independently authored reporting stays in its own paragraph.</p>
      </div></section>#{fallback}</main>
    HTML
  end

  def observe_publication_credit(mode)
    with_url_page('https://publication.example.test/catalogue', publication_credit_source(mode)) do |page|
      before = page.evaluate('document.body.outerHTML')
      inject_standalone_extractor(page, reader_mode: true)
      page.add_script_tag(content: publication_credit_probe)
      result = page.evaluate("publicationCreditProbe(#{mode.to_json})")
      expect(result.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield result
    end
  end

  it 'does not add another paragraph for the exact complete physical field already rendered by its record' do
    observe_publication_credit('plain') do |result|
      expect(result.fetch('parts')).to eq([])
      expect(result.fetch('markdown')).to eq(
        '- [River report 307](https://publication.example.test/issues/issue-307/river/?edition=2&view=full#details) - Cover | Ari Lens' \
        ' - [Publication number 307](https://publication.example.test/issues/issue-307/) Issue 307'
      )
      expect(result.fetch('sourceCredits').map { |node| node.fetch('text') }).to eq(['Cover | Ari Lens'])
    end
  end

  it 'retains an independent equal-valued physical credit rather than collapsing its text' do
    observe_publication_credit('independent') do |result|
      expect(result.fetch('parts')).to eq(['Cover | Ari Lens'])
      expect(result.fetch('markdown').scan('Cover | Ari Lens').size).to eq(1)
      expect(result.fetch('sourceCredits').map { |node| node.fetch('text') }).to eq(['Cover | Ari Lens'] * 2)
    end
  end

  it 'keeps a credit when compact context collides with another independently declared field' do
    observe_publication_credit('collision') do |result|
      expect(result.fetch('parts')).to eq(['Cover | Ari Lens'])
      expect(result.fetch('markdown').scan('Cover | Ari Lens').size).to eq(1)
    end
  end

  it 'does not waive rich material, named targets, unrendered group context or physical visibility' do
    { 'rich' => ['**Cover | Ari Lens**'], 'named' => ['Cover | Ari Lens'],
      'group' => ['Cover | Ari Lens'], 'hidden' => [] }.each do |mode, expected|
      observe_publication_credit(mode) do |result|
        expect(result.fetch('parts')).to eq(expected)
        expect(result.fetch('markdown')).not_to include('Cover | Ari Lens') if %w[group hidden].include?(mode)
      end
    end
  end

  it 'does not attribute an independent fallback value to an empty owned metadata declaration' do
    observe_publication_credit('fallback') do |result|
      expect(result.fetch('sourceCredits').map { |node| node.fetch('text') }).to eq(['Cover | Ari Lens'])
      expect(result.fetch('markdown').scan('Cover | Ari Lens').size).to eq(1)
      expect(result.fetch('parts')).to eq(['Cover | Ari Lens'])
    end
  end
end
