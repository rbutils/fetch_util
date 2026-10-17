# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reader header date excerpts', :integration do
  include_context 'extractor integration helpers'

  def dated_section_article
    <<~HTML
      <!doctype html><html lang="en"><head><title>A public reference guide - Example Review</title></head>
      <body><div class="post"><h1>A public reference guide</h1>
      <span class="post-date">06 Oct 2020</span><p>Last updated: November 2 2025</p>
      <h2 id="source-methods">Finding the complete public sources</h2>
      <p id="lead">This guide explains three independent ways to obtain the complete public records, compare their limitations and verify every available source.</p>
      <p id="detail">The second paragraph supplies the full reporting context and an <a href="/sources">independent reference</a> for readers.</p>
      <h3 id="source-analysis">Analysing the published records</h3>
      <p id="analysis">The published analysis preserves its observations, all source resources and the complete explanation of the method used by the author.</p>
      <pre><code>read_complete_records()
      verify_every_source()</code></pre></div></body></html>
    HTML
  end

  def reader_header_date_probe
    paths = File.read(File.expand_path('../../../websieve/manifest.txt', __dir__)).lines.map(&:strip)
                .reject { |line| line.empty? || line.start_with?('#') }
    source = paths.map { |path| File.read(File.expand_path("../../../websieve/#{path}", __dir__)) }.join("\n")
    boundary = '})(window);'
    expect(source.scan(boundary).length).to eq(1)
    expose = <<~JS
      global.readerHeaderDateProbe = function(change) {
        return withComposedDomRead(function() {
          var clone = safeReadableDocumentClone();
          var mappings = new Map();
          pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, mappings);
          var marker = 'header-date-probe';
          var identities = markReadabilitySourceNodeProvenance(clone, mappings, marker);
          var snapshots = readerSectionHeadingSnapshots(clone, {title: document.title}, mappings, identities, marker);
          var date = clone.querySelector('.post-date');
          if (!date) return null;
          var paragraph = clone.createElement('p');
          paragraph.textContent = date.textContent;
          date.replaceWith(paragraph);
          var owner = clone.querySelector('.post');
          var evidence = sourceOwnedReaderSelectedParagraphs(owner, mappings, identities, marker, true);
          var article = {title: 'A public reference guide', excerpt: '06 Oct 2020', content: owner.innerHTML};
          if (change === 'empty-title') article.title = '';
          if (change === 'title') article.title = 'A conflicting selected title';
          if (change === 'summary') article.excerpt = 'A genuine editorial summary remains authoritative.';
          if (change === 'unmapped') evidence = null;
          if (change === 'foreign') evidence.sourceParagraphs = [document.querySelector('h1')];
          return readerSectionHeaderDateExcerpt(article, evidence, snapshots);
        })({});
      };
    JS
    source.sub(boundary, "#{expose}\n#{boundary}")
  end

  it 'uses the retained first section paragraph while preserving both header dates and the complete source body' do
    with_url_page('https://reference.example.test/guide', dated_section_article) do |page|
      before = page.evaluate('document.body.innerHTML')
      lead = page.evaluate('document.querySelector("#lead").textContent')
      result = extract(page)
      expect(result.fetch('excerpt')).to eq(lead)
      expect(result.fetch('html')).to include('06 Oct 2020', 'Last updated: November 2 2025')
      expect(result.fetch('markdown')).to include('read_complete_records()', 'verify_every_source()', '/sources')
      expect(result.fetch('html')).to include('source-methods', 'source-analysis')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'requires a unique visible header field, an uninterrupted date-only header and exact paragraph provenance' do
    with_url_page('https://reference.example.test/guide', dated_section_article) do |page|
      page.evaluate(reader_header_date_probe)
      before = page.evaluate('document.body.innerHTML')
      values = page.evaluate(<<~JS)
        (() => {
          const original = document.body.innerHTML;
          const positive = window.readerHeaderDateProbe();
          const changes = [
            () => document.querySelector('.post-date').hidden = true,
            () => document.querySelector('.post-date').after(document.querySelector('.post-date').cloneNode(true)),
            () => document.querySelector('h1').textContent = 'An unrelated document heading',
            () => document.querySelector('.post-date').insertAdjacentHTML('afterend', '<p>A brief authored opening must not be skipped.</p>'),
            () => document.querySelector('#lead').insertAdjacentHTML('afterbegin', '<button>Open a different source</button>'),
            () => document.querySelector('.post-date').removeAttribute('class'),
            () => document.querySelector('.post-date').setAttribute('role', 'button'),
            () => document.querySelector('.post-date').nextElementSibling.setAttribute('role', 'button')
          ];
          const declined = changes.map(change => {
            change();
            const value = window.readerHeaderDateProbe();
            document.body.innerHTML = original;
            return value === null;
          });
          return {positive, declined, summary: window.readerHeaderDateProbe('summary'),
            unmapped: window.readerHeaderDateProbe('unmapped'), foreign: window.readerHeaderDateProbe('foreign'),
            empty_title: window.readerHeaderDateProbe('empty-title'), title: window.readerHeaderDateProbe('title'),
            restored: window.readerHeaderDateProbe(), unchanged: document.body.innerHTML === original};
        })()
      JS
      expect(values.fetch('positive')).to eq(page.evaluate('document.querySelector("#lead").textContent'))
      expect(values.fetch('declined')).to eq([true] * 8)
      expect(values.values_at('summary', 'unmapped', 'foreign')).to eq([nil, nil, nil])
      expect(values.fetch('title')).to be_nil
      expect(values.fetch('empty_title')).to eq(values.fetch('positive'))
      expect(values.fetch('restored')).to eq(values.fetch('positive'))
      expect(values.fetch('unchanged')).to be(true)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
