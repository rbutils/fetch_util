# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'FetchUtil source-owned publication credit descriptions' do
  include_context 'extractor integration helpers'

  def publication_credit_probe_source
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    marker = '})(window);'
    raise 'ambiguous description probe boundary' unless source.scan(marker).length == 1
    source.sub(marker, <<~JAVASCRIPT)
      global.probePublicationCreditDescriptions = function(completePublication) {
        var before = document.body.innerHTML;
        var root = document.querySelector('main');
        var primary = document.querySelector('#primary a');
        var items = [{ sourceNode: primary, orderNode: primary, card: primary.closest('article'),
          text: primary.textContent, url: primary.href, sourceOrderedRepeatedRecord: true }];
        if (completePublication) {
          var cover = document.querySelector('#publication-307 .cover-link');
          items.push({ sourceNode: cover, orderNode: cover, card: cover.closest('section'),
            text: 'Issue 307', url: cover.href, sourceOrderedRepeatedRecord: true });
        }
        var parts = listDescriptionParts(root, items, {
          preserveUnselectedRecordMaterial: true, includeInlineProse: true,
          preserveTextLengths: true, preserveUnrepresentedText: true,
          suppressRepresentedText: true, pageTitles: [document.title]
        });
        var markdown = sectionedListMarkdownWithDescriptions({
          regions: [{ node: root, label: '', cards: items }]
        }, parts);
        return {
          markdown: markdown,
          sourceCreditValues: Array.from(document.querySelectorAll('.publication-author'), function(node) {
            return node.textContent;
          }),
          program: document.querySelector('pre').textContent,
          references: Array.from(document.querySelectorAll('a[href]'), function(link) {
            return [link.textContent, link.href];
          }),
          images: Array.from(document.querySelectorAll('img'), function(image) {
            return [image.getAttribute('alt'), image.src];
          }),
          unchanged: before === document.body.innerHTML
        };
      };
      })(window);
    JAVASCRIPT
  end

  def publication_credit_html(paragraph: false, formatted: false, hidden: false, closed: false, profile: false)
    records = [307, 308].map do |number|
      credit = formatted ? 'Cover | <em>Ari Lens</em>' : 'Cover | Ari Lens'
      field = "<span class='publication-author'#{hidden && number == 307 ? " style='display:none'" : ""}>#{credit}</span>"
      field = "<p>#{field}</p>" if paragraph
      destination = profile ? '/authors/ari-lens/' : "/issues/issue-#{number}/"
      record = <<~HTML
        <section id="publication-#{number}"><div class="cover-column">
          <a class="cover-link" href="#{destination}"><img src="/cover-#{number}.jpg" alt="Publication #{number}"></a>
          #{field}<button><a href="/issues/">All publications</a></button>
        </div><div class="contents-column"><h1>Issue #{number}</h1>
          <h2><a href="/reports/#{number}/">The complete independent report #{number}</a></h2>
          <p>The complete authored publication introduction for issue #{number} is retained.</p>
        </div></section>
      HTML
      closed && number == 307 ? "<details><summary>Issue details</summary>#{record}</details>" : record
    end.join
    <<~HTML
      <!doctype html><html><head><title>Publication catalogue</title>
      <link rel="canonical" href="https://publication.example.test/catalogue/"></head><body>
      <main><h1>Publication catalogue</h1><article id="primary">
        <h2><a href="/reports/primary/">The complete primary reporting record</a></h2>
        <p>The independently authored primary paragraph remains complete and in source order.</p>
        <pre>first_code()

      last_code()</pre></article>#{records}</main></body></html>
    HTML
  end

  def publication_credit_probe(html, complete_publication: false)
    with_url_page('https://publication.example.test/catalogue/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      inject_standalone_extractor(page)
      page.add_script_tag(content: publication_credit_probe_source)
      value = page.evaluate("probePublicationCreditDescriptions(#{complete_publication})")
      expect(value.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(value.fetch('sourceCreditValues')).to eq(['Cover | Ari Lens', 'Cover | Ari Lens'])
      expect(value.fetch('program')).to eq("first_code()\n\nlast_code()")
      expect(value.fetch('markdown')).to include("first_code()\n\nlast_code()")
      expect(value.fetch('references').length).to eq(7)
      expect(value.fetch('images')).to eq(
        [
          ['Publication 307', 'https://publication.example.test/cover-307.jpg'],
          ['Publication 308', 'https://publication.example.test/cover-308.jpg']
        ]
      )
      yield(value.fetch('markdown'))
    end
  end

  it 'retains both independently owned inline credit occurrences in list descriptions' do
    publication_credit_probe(publication_credit_html) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(2)
      expect(markdown.index('Publication 307')).to be < markdown.index('Cover | Ari Lens')
      expect(markdown.rindex('Cover | Ari Lens')).to be < markdown.index('Issue 308')
    end
  end

  it 'retains the authored emphasis within an independently owned credit' do
    publication_credit_probe(publication_credit_html(formatted: true)) do |markdown|
      expect(markdown.scan(/(?<![*_])([*_])Ari Lens\1(?![*_])/).length).to eq(2)
    end
  end

  it 'does not duplicate a credit already retained by its authored paragraph' do
    publication_credit_probe(publication_credit_html(paragraph: true)) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(2)
    end
  end

  it 'keeps a source-hidden credit hidden beside a visible independent occurrence' do
    publication_credit_probe(publication_credit_html(hidden: true)) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(1)
    end
  end

  it 'keeps the credit in a closed disclosure closed' do
    publication_credit_probe(publication_credit_html(closed: true)) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(1)
    end
  end

  it 'does not promote an unproved person-profile field to supplemental publication material' do
    publication_credit_probe(publication_credit_html(profile: true)) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(0)
    end
  end

  it 'does not duplicate a credit in a completely represented physical publication record' do
    publication_credit_probe(publication_credit_html, complete_publication: true) do |markdown|
      expect(markdown.scan('Cover | Ari Lens').length).to eq(2)
    end
  end
end
