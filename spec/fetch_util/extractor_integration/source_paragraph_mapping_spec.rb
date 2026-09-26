# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reader source paragraph mapping' do
  include_context 'extractor integration helpers'

  def article_page(break_pairs: 1)
    segments = ['For example, a painter may promise to paint a home in exchange for payment from the homeowner.']
    segments << 'In another example, a tenant may promise to pay rent for continued use of a home.' if break_pairs == 2
    breaks = segments.map { |segment| "<br><br><span>#{segment}</span>" }.join
    <<~HTML
      <!doctype html><html><head>
      <title>consideration | Reference Journal</title>
      <meta property="og:site_name" content="Reference Journal">
      </head><body><main id="main-content">
      <h1 id="page-title">consideration</h1>
      <p id="definition">Consideration means the mutual exchange of promises or obligations between the parties to a contract.
      It is a necessary element in the creation of an enforceable agreement.<a href="/terms/contract">A contract</a> binds each party to a promise.
      #{breaks}</p>
      <p id="application">A court may evaluate whether each party assumed an obligation when the agreement was made.
      The source explanation applies that rule to the facts and preserves the order of the parties' promises.</p>
      </main></body></html>
    HTML
  end

  def paragraph_mapping_probe(page, mode: 'complete')
    extract_payload(page)
    root = File.expand_path('../../..', __dir__)
    paths = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
    paths.reject! { |path| path.empty? || path.start_with?('#') }
    sources = paths.map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    page.add_script_tag(content: sources.sub(
      '})(window);',
      'window.__markReaderSources = markReadabilitySourceNodeProvenance; ' \
      'window.__readerParagraphOwners = sourceOwnedReaderSelectedParagraphs; ' \
      'window.__sourceBreakSegments = sourceParagraphBreakSegments; ' \
      'window.__normalizeReaderText = normalizeText; })(window);'
    ))
    page.evaluate(<<~JS)
      (() => {
        const marker = 'paragraph-mapping-spec';
        const sourceHeadline = document.querySelector('#main-content > h1');
        const sourceParagraphs = Array.from(document.querySelectorAll('#main-content > p'));
        const sourceClones = new Map();
        const sourceRoot = document.createElement('div');
        [sourceHeadline, ...sourceParagraphs].forEach((source) => {
          const clone = source.cloneNode(true);
          sourceRoot.appendChild(clone);
          sourceClones.set(source, clone);
        });
        const identities = window.__markReaderSources(sourceRoot, sourceClones, marker);
        const firstClone = sourceClones.get(sourceParagraphs[0]);
        const firstIdentity = identities.get(sourceParagraphs[0]);
        const readerRoot = document.createElement('div');
        const retainedHeadline = document.createElement('h2');
        retainedHeadline.id = sourceHeadline.id;
        retainedHeadline.textContent = sourceHeadline.textContent;
        readerRoot.appendChild(retainedHeadline);

        const splitOwner = document.createElement('div');
        splitOwner.id = firstClone.id;
        splitOwner.setAttribute('data-fetchutil-reader-source-paragraph',
          firstClone.getAttribute('data-fetchutil-reader-source-paragraph'));
        let segments = firstIdentity.breakSegments.slice();
        if (#{JSON.generate(mode)} === 'missing') segments.pop();
        if (#{JSON.generate(mode)} === 'reordered') segments.reverse();
        if (#{JSON.generate(mode)} === 'duplicated') segments.splice(1, 0, segments[0]);
        if (#{JSON.generate(mode)} === 'mutated-segment') segments[0] += ' foreign addition';
        segments.forEach((text) => {
          const paragraph = document.createElement('p');
          paragraph.textContent = text;
          splitOwner.appendChild(paragraph);
        });
        readerRoot.appendChild(splitOwner);

        if (#{JSON.generate(mode)} !== 'one-source-only') {
          const secondClone = sourceClones.get(sourceParagraphs[1]);
          const second = document.createElement('p');
          second.id = secondClone.id;
          second.textContent = #{JSON.generate(mode)} === 'mutated-anchored-paragraph'
            ? 'This text no longer matches the complete source-visible paragraph.'
            : secondClone.textContent;
          readerRoot.appendChild(second);
        }
        if (#{JSON.generate(mode)} === 'interleaved-source') {
          const continuation = splitOwner.cloneNode(false);
          continuation.appendChild(splitOwner.lastElementChild);
          readerRoot.appendChild(continuation);
        }
        if (#{JSON.generate(mode)} === 'foreign-matching-text') {
          const foreign = document.createElement('p');
          foreign.textContent = firstIdentity.breakSegments[0];
          readerRoot.appendChild(foreign);
        }

        const owners = window.__readerParagraphOwners(readerRoot, sourceClones, identities, marker);
        return {
          accepted: !!owners,
          sourceIds: owners && owners.map((source) => source.id || null),
          splitSegments: firstIdentity.breakSegments,
          sourceStillIntact: window.__normalizeReaderText(sourceParagraphs[0].textContent) === firstIdentity.visibleText
        };
      })()
    JS
  end

  it 'restores the source headline after Reader splits one explicit source break pair' do
    extract_from_url('https://legal-notes.example/consideration', article_page) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['readerMode']).to be(true)
      expect(payload['title']).to eq('consideration')
      expect(payload['html']).to include('<h1 id="page-title">consideration</h1>')
      expect(payload['html']).to include('mutual exchange of promises', 'For example, a painter may promise')
      expect(payload['html']).to include('href="https://legal-notes.example/terms/contract"')
      expect(payload['html']).not_to match(/data-fetchutil-reader-source-(?:headline|paragraph)|fetchutil-reader-/)
    end
  end

  it 'maps multiple exact segments through their retained source-paragraph ancestor' do
    with_url_page('https://legal-notes.example/consideration', article_page(break_pairs: 2)) do |page|
      result = paragraph_mapping_probe(page)
      expect(result.fetch('accepted')).to be(true)
      expect(result.fetch('sourceIds')).to eq(%w[definition application])
      expect(result.fetch('splitSegments').length).to eq(3)
      expect(result.fetch('sourceStillIntact')).to be(true)
    end
  end

  it 'rejects incomplete, reordered, duplicated, mutated, or interleaved source segments' do
    %w[missing reordered duplicated mutated-segment interleaved-source].each do |mode|
      with_url_page('https://legal-notes.example/consideration', article_page(break_pairs: 2)) do |page|
        expect(paragraph_mapping_probe(page, mode: mode).fetch('accepted')).to be(false), mode
      end
    end
  end

  it 'requires a whole ID-mapped paragraph to match its complete source-visible text' do
    with_url_page('https://legal-notes.example/consideration', article_page) do |page|
      result = paragraph_mapping_probe(page, mode: 'mutated-anchored-paragraph')
      expect(result.fetch('accepted')).to be(false)
    end
  end

  it 'rejects unmarked foreign text equal to a source segment and a single source-P witness' do
    %w[foreign-matching-text one-source-only].each do |mode|
      with_url_page('https://legal-notes.example/consideration', article_page) do |page|
        expect(paragraph_mapping_probe(page, mode: mode).fetch('accepted')).to be(false), mode
      end
    end
  end
end
