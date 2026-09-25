# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Article and linked-resource author ownership' do
  include_context 'extractor integration helpers'

  def linked_resource_article(metadata: '', byline: '', card_author: 'Reference Publisher', card_marker: 'class="preview-author-name"')
    <<~HTML
      <html><head><title>A report on river restoration</title>#{metadata}</head><body><main><article>
        <header><h1>A report on river restoration</h1>#{byline}</header>
        <p>The restoration team surveyed the river after months of careful work, recording the changes in its flow and surrounding habitat.</p>
        <figure><a href="https://reference.example/river-report">
          <div>Independent reference report</div><div>A detailed account of related restoration work and its environmental results.</div>
          <div><span #{card_marker}>#{card_author}</span><img src="https://reference.example/cover.jpg" alt="Reference report cover"></div>
        </a></figure>
        <p>Engineers compared the new measurements with their earlier observations and explained the evidence behind their conclusions.</p>
        <p>Local residents described improvements in the landscape and the team outlined its plans for further monitoring during the next season.</p>
      </article></main></body></html>
    HTML
  end

  it 'keeps declared article authors and preserves the linked resource attribution in content' do
    html = linked_resource_article(metadata: '<meta name="author" content="River Reporter">')
    with_url_page('https://reports.example/river', html) do |page|
      original_body = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      expect(payload['byline']).to eq('River Reporter')
      expect(payload['markdown']).to include('Reference Publisher', 'Independent reference report', 'https://reference.example/river-report')
      expect(payload['html']).to include('https://reference.example/cover.jpg')
      expect(page.evaluate('document.body.innerHTML')).to eq(original_body)
    end
  end

  it 'does not invent an article author from a linked card when article attribution is absent' do
    ['class="preview-author-name"', 'id="reference-byline"', 'itemprop="author"', 'rel="author"'].each do |marker|
      extract_from_url('https://reports.example/river', linked_resource_article(card_marker: marker)) do |payload|
        expect(payload['byline']).to be_nil
        expect(payload['markdown']).to include('Reference Publisher', 'Independent reference report')
      end
    end
  end

  it 'preserves a genuine header author even when the same name also occurs in a reference card' do
    byline = '<figure><a href="/author/river-reporter" rel="author">River Reporter</a></figure>'
    html = linked_resource_article(byline: byline, card_author: 'River Reporter')
    extract_from_url('https://reports.example/river', html) do |payload|
      expect(payload['byline']).to eq('River Reporter')
      expect(payload['markdown']).to include('River Reporter', 'Independent reference report')
    end
  end

  it 'keeps fragment links to a card attribution identifier intact' do
    html = linked_resource_article(card_marker: 'id="reference-byline"').sub(
      '</article>', '<p>Read the <a href="#reference-byline">reference credit</a> alongside the report.</p></article>'
    )
    extract_from_url('https://reports.example/river', html) do |payload|
      expect(payload['byline']).to be_nil
      expect(payload['html']).to include('id="reference-byline"')
      expect(payload['markdown']).to include('[reference credit](https://reports.example/river#reference-byline)')
      expect(payload['markdown']).to include('Reference Publisher')
    end
  end
end
