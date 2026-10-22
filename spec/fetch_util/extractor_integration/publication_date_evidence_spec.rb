# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'
require 'cgi'

RSpec.describe 'Source evidence for inferred publication dates' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://publication.example.test/reference/date-evidence' }
  let(:program) { "published = 'Scrollen'\nputs published" }
  let(:lead) do
    'This publication explains the evidence needed to reproduce its observations. ' \
      'Every original value, independent reference, and complete program remains available to the reader.'
  end

  def date_evidence_page(fragment, declaration: '')
    <<~HTML
      <!doctype html><html><head><title>Publication date evidence</title>
      <link rel="canonical" href="#{page_url}">#{declaration}</head><body>
      <article class="field--name-body" role="main"><header><h1>Publication date evidence</h1></header>
      #{fragment}
      <p>#{lead}</p><h2>Complete method</h2>
      <p>The published method distinguishes an actual date from a navigation label, an unrelated style name, or an unknown future schedule. These distinctions do not remove the original explanation.</p>
      <pre><code>#{CGI.escapeHTML(program)}</code></pre>
      <p>Read the <a href="/reference/source">independent source</a> before interpreting the observations.</p>
      </article></body></html>
    HTML
  end

  def extract_date_evidence(fragment, declaration: '')
    with_url_page(page_url, date_evidence_page(fragment, declaration: declaration)) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(payload.fetch('title')).to eq('Publication date evidence')
      expect(payload.fetch('markdown')).to include(lead, 'Complete method', 'independent source', '/reference/source')
      programs = Nokogiri::HTML.fragment(payload.fetch('html')).css('pre').map(&:text)
      expect(programs).to eq([program])
      yield payload
    end
  end

  {
    'unpublished styling' => '<div class="paragraph--unpublished"><a href="#method">Scrollen</a></div>',
    'unrelated date substring' => '<div class="datenschutz"><a href="/privacy">Data Protection</a></div>',
    'unknown schedule text' => '<p class="hero-date"><span class="hero-date-range is-tba">待定</span></p>'
  }.each do |name, fragment|
    it "does not infer a publication date from #{name}" do
      extract_date_evidence(fragment) do |payload|
        expect(payload['publishedTime']).to be_nil
      end
    end
  end

  it 'does not borrow a real date from a navigation-owned time element' do
    fragment = '<nav aria-label="Archive"><a href="/archive"><time datetime="2027-11-12">12 November 2027</time></a></nav>'
    extract_date_evidence(fragment) do |payload|
      expect(payload['publishedTime']).to be_nil
    end
  end

  it 'retains recognizable independent dates despite preceding misleading classes' do
    values = ['2026-04-07', '7 avril 2026', '١٢ أكتوبر ٢٠٢٦', '2026年4月7日', 'yesterday']
    values.each do |value|
      fragment = '<div class="paragraph--unpublished">Read the method</div>' \
                 "<span class=\"published-date\">#{value}</span>"
      extract_date_evidence(fragment) do |payload|
        expect(payload.fetch('publishedTime')).to eq(value.tr('٠١٢٣٤٥٦٧٨٩', '0123456789'))
      end
    end
  end

  it 'preserves an explicitly declared semantic datetime outside the heuristic numeral scripts' do
    value = '२०२६-०४-०७'
    fragment = "<time itemprop=\"datePublished\" datetime=\"#{value}\">७ अप्रैल २०२६</time>"
    extract_date_evidence(fragment) do |payload|
      expect(payload.fetch('publishedTime')).to eq(value)
    end
  end

  it 'preserves the identity-bound publisher WebPage declaration' do
    value = '2026-04-07T10:20:00Z'
    entity = {
      '@context' => 'https://schema.org', '@type' => 'WebPage', '@id' => page_url,
      'url' => page_url, 'name' => 'Publication date evidence', 'datePublished' => value
    }
    declaration = "<script type=\"application/ld+json\">#{JSON.generate(entity)}</script>"
    extract_date_evidence('<div class="datenschutz">Data Protection</div>', declaration: declaration) do |payload|
      expect(payload.fetch('publishedTime')).to eq(value)
    end
  end
end
