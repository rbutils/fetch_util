# frozen_string_literal: true

require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe 'Publication dates outside interactive controls' do
  include_context 'extractor integration helpers'

  let(:page_url) { 'https://publication.example.test/reference/shared-methods' }
  let(:program) { "date_label = \"Starts Oct 16\"\nputs date_label" }
  let(:lead) do
    'The shared methods explain how independent readers can reproduce every published observation. ' \
      'The complete reference preserves original values, their ordering, and the sources used by the authors.'
  end

  def publication_page(control:, declaration: '', publication: '')
    <<~HTML
      <html><head><title>Shared reference methods</title>
        <link rel="canonical" href="#{page_url}">#{declaration}
      </head><body><main>
        <header><h1>Shared reference methods</h1>#{publication}</header>
        #{control}
        <section><h2>Complete methods</h2><p>#{lead}</p>
          <p>Researchers retain every independent result and the complete discussion of their methods. This account explains the original experiment, its limitations, and the observations needed for reproduction.</p>
          <pre><code>#{program}</code></pre>
          <p>The full reference includes the original program and an independent resource so readers can inspect both the evidence and its interpretation.</p>
          <p><a href="/reference/source">Original reference</a></p>
        </section>
      </main></body></html>
    HTML
  end

  def native_date_control
    '<form><button type="submit"><span><div class="startdate" data-testid="start-date-string">' \
      'Starts Oct 16</div></span></button></form>'
  end

  def visible_control_date(page)
    root = File.expand_path('../..', File.dirname(FetchUtil::Extractor.instance_method(:extract).source_location.first))
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |path| path.empty? || path.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    export = 'window.__publicationFallbackProbe = function() { return visiblePublishedTime(document.querySelector("main")); };'
    raise 'extractor closure boundary changed' unless source.scan('})(window);').size == 1

    page.add_script_tag(content: source.sub('})(window);', "#{export}\n})(window);"))
    page.evaluate('window.__publicationFallbackProbe()')
  end

  def extract_publication_page(html)
    with_url_page(page_url, html) do |page|
      before = page.evaluate('document.body.innerHTML')
      fallback = visible_control_date(page)
      result = extract(page)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      expect(result.fetch('title')).to eq('Shared reference methods')
      expect(result.fetch('markdown')).to include(lead, 'Original reference', '/reference/source')
      values = page.evaluate(<<~JS)
        (function() {
          var holder = document.createElement('div');
          holder.innerHTML = #{result.fetch("html").to_json};
          return Array.from(holder.querySelectorAll('pre code')).map(function(node) { return node.textContent; });
        })()
      JS
      expect(values).to eq([program])
      yield result, fallback
    end
  end

  it 'does not borrow the displayed start date inside a native submit button' do
    extract_publication_page(publication_page(control: native_date_control)) do |result, fallback|
      expect(fallback).to be_nil
      expect(result['publishedTime']).to be_nil
    end
  end

  it 'does not treat a time element inside an ARIA button as publication' do
    control = '<div role="button" tabindex="0"><time datetime="2027-11-12">12 November 2027</time></div>'
    extract_publication_page(publication_page(control: control)) do |result, fallback|
      expect(fallback).to be_nil
      expect(result['publishedTime']).to be_nil
    end
  end

  it 'retains the independent visible publication time after conflicting controls' do
    control = '<button type="button"><time datetime="2027-11-12">12 November 2027</time></button>'
    publication = '<p>Published <time datetime="2026-04-07">7 April 2026</time></p>'
    extract_publication_page(publication_page(control: control, publication: publication)) do |result, fallback|
      expect(fallback).to eq('2026-04-07')
      expect(result.fetch('publishedTime')).to eq('2026-04-07')
    end
  end

  it 'retains the explicit HEAD publication declaration despite control dates' do
    declaration = '<meta property="article:published_time" content="2026-04-07T10:20:00Z">'
    extract_publication_page(publication_page(control: native_date_control, declaration: declaration)) do |result|
      expect(result.fetch('publishedTime')).to eq('2026-04-07T10:20:00Z')
    end
  end
end
