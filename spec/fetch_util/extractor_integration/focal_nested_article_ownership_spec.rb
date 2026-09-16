# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'generic focal nested article ownership' do
  include_context 'extractor integration helpers'

  let(:article_title) { 'River restoration protects four districts' }

  def article_body(tag: 'article', attributes: 'class="news-content"')
    <<~HTML
      <#{tag} #{attributes}>
        <h1>#{article_title}</h1>
        <p>The restoration project reconnects four districts while protecting homes that flooded during three consecutive winters.</p>
        <p>Engineers rebuilt the riverbanks after reviewing historical maps, drainage records, and testimony from residents.</p>
        <p>Independent researchers measured water levels throughout the work and published the complete monitoring data.</p>
        <p>The final design preserves wetlands beside the railway bridge and creates safer walking routes between neighborhoods.</p>
      </#{tag}>
    HTML
  end

  def localized_story_rail(class_name: 'stream')
    cards = Array.new(7) do |index|
      <<~HTML
        <div class="stream-item">
          <h2><a href="/meldung/#{index + 1}">Regionale Meldung Nummer #{index + 1}</a></h2>
          <p>Diese Meldung beschreibt ein anderes Ereignis aus der Region und gehört nicht zum ausführlichen Flussbericht.</p>
        </div>
      HTML
    end.join

    <<~HTML
      <section class="#{class_name}">
        <h2>Weitere Meldungen</h2>
        #{cards}
      </section>
    HTML
  end

  def fallback_result(url, html)
    result = nil
    with_url_page(url, html) do |page|
      source_body = page.evaluate('document.body.innerHTML')
      result = extract_payload(page, reader_mode: false)
      expect(page.evaluate('document.body.innerHTML')).to eq(source_body)
    end
    result
  end

  %w[main article div].each do |wrapper|
    it "prefers one focal article over a longer localized rail in a broad #{wrapper} wrapper" do
      result = fallback_result(
        'https://example.test/news/river-restoration',
        <<~HTML
          <!doctype html>
          <html><head><title>#{article_title}</title></head><body>
            <#{wrapper} class="page-layout">
              #{article_body}
              #{localized_story_rail(class_name: "related-stories")}
            </#{wrapper}>
          </body></html>
        HTML
      )

      expect(result.fetch('contentType')).to eq('article')
      expect(result.fetch('markdown')).to include('The restoration project reconnects four districts')
      expect(result.fetch('markdown')).not_to include('Weitere Meldungen')
      expect(result.fetch('markdown')).not_to include('Regionale Meldung Nummer')
    end
  end

  it 'uses structural ownership across common article body selector families' do
    shapes = {
      'article area' => ['div', 'class="layout articleArea_primary"'],
      'news content' => ['div', 'class="news-content"'],
      'article body' => ['div', 'class="article-body"'],
      'post content' => ['div', 'class="post-content"'],
      'details content' => ['div', 'class="details-content"'],
      'news details article' => ['article', 'class="news-details-content"'],
      'schema article body' => ['div', 'itemprop="articleBody"']
    }

    shapes.each_with_index do |(label, (tag, attributes)), index|
      result = fallback_result(
        "https://example.test/news/article-selector-#{index + 1}",
        <<~HTML
          <html><head><title>#{article_title}</title></head><body><main class="page-layout">
            #{article_body(tag: tag, attributes: attributes)}
            #{localized_story_rail(class_name: "related-stories")}
          </main></body></html>
        HTML
      )

      expect(result.fetch('markdown')).to include('The restoration project reconnects four districts'), label
      expect(result.fetch('markdown')).not_to include('Weitere Meldungen'), label
    end
  end

  it 'does not choose one focal record from a collection of independent articles' do
    records = Array.new(4) do |index|
      title = index.zero? ? 'Independent reporting archive' : "Independent report number #{index + 1}"
      <<~HTML
        <article>
          <h2><a href="/reports/#{index + 1}">#{title}</a></h2>
          <p>This report covers its own public event and contains independently attributed reporting from several public meetings.</p>
          <p>Its evidence and conclusions are separate from every neighboring report in this collection and its archived records.</p>
          <p>Readers can follow the destination for the complete record, supporting documents, interviews, and verified measurements.</p>
          <p>Each independent report remains a peer record even when one title happens to match the name of the collection.</p>
        </article>
      HTML
    end.join

    result = fallback_result(
      'https://example.test/news/reports/',
      "<html><head><title>Independent reporting archive</title></head><body><main><h1>Independent reporting archive</h1>#{records}</main></body></html>"
    )

    expect(result.fetch('contentType')).to eq('list')
    expect(result.fetch('markdown').scan(%r{https://example\.test/reports/\d})).to eq(
      (1..4).map { |number| "https://example.test/reports/#{number}" }
    )
  end

  it 'keeps a separate collection of short peer articles beside a focal article' do
    records = Array.new(3) do |index|
      <<~HTML
        <article>
          <h2><a href="/districts/#{index + 1}">District report number #{index + 1}</a></h2>
          <p>This independently reported district record summarizes public meetings, verified measurements, and attributed local evidence.</p>
        </article>
      HTML
    end.join

    result = fallback_result(
      'https://example.test/news/district-reports',
      <<~HTML
        <html><head><title>#{article_title}</title></head><body><main>
          #{article_body}
          <section class="collection"><h2>Independent district reporting</h2>#{records}</section>
        </main></body></html>
      HTML
    )

    expect(result.fetch('markdown').scan(%r{https://example\.test/districts/\d})).to eq(
      (1..3).map { |number| "https://example.test/districts/#{number}" }
    )
  end

  it 'keeps a broad owner when substantive prose outside the focal child is not rail material' do
    result = fallback_result(
      'https://example.test/news/river-restoration-supporting-analysis',
      <<~HTML
        <html><head><title>#{article_title}</title></head><body><article class="page-layout">
          <h2>Investigation context</h2>
          <span>Compiled from regional monitoring records.</span>
          <p>The editorial introduction explains why this investigation combines the focal report with a separately authored methodology note.</p>
          #{article_body}
          <section><h2>Methodology note</h2><p>This substantive sibling analysis explains sampling limitations and must not be discarded as story-rail furniture.</p></section>
          #{localized_story_rail}
        </article></body></html>
      HTML
    )

    expect(result.fetch('markdown')).to include('editorial introduction explains')
    expect(result.fetch('markdown')).to include('substantive sibling analysis')
    expect(result.fetch('markdown')).to include('Compiled from regional monitoring records')
  end

  it 'does not let hidden or complementary candidates establish focal ownership' do
    hidden_body = article_body(attributes: 'class="news-content" style="display: none"')
    complementary_body = article_body(attributes: 'class="news-content" role="COMPLEMENTARY"')
    result = fallback_result(
      'https://example.test/news/hidden-focal-candidates',
      <<~HTML
        <html><head><title>#{article_title}</title></head><body><main class="page-layout">
          #{hidden_body}
          <aside>#{complementary_body}</aside>
          #{localized_story_rail}
        </main></body></html>
      HTML
    )

    expect(result.fetch('markdown')).not_to include('The restoration project reconnects four districts')
    expect(result.fetch('markdown')).to include('Regionale Meldung Nummer 1')
  end

  it 'keeps broad ownership when visible material exists outside the focal article and rail' do
    material = {
      'short note' => ['<div class="editor-note">Residents should retain this short evacuation warning.</div>', 'Residents should retain'],
      'figure' => [
        '<figure><img src="/chart.png" alt="Water level chart"><figcaption>Independent monitoring chart.</figcaption></figure>',
        'Independent monitoring chart'
      ],
      'bare media' => ['<img src="/map.png" alt="District flood map">', nil],
      'linked heading' => ['<h2><a href="/analysis">Independent analysis</a></h2>', 'Independent analysis'],
      'comment role' => ['<section role="COMMENT"><div>A resident supplied first-hand context.</div></section>', 'A resident supplied'],
      'live feed' => ['<section role="feed" data-liveblog><div>Monitoring teams issued a live update.</div></section>', 'Monitoring teams issued']
    }

    material.each_with_index do |(label, (sibling, expected)), index|
      result = fallback_result(
        "https://example.test/news/outside-material-#{index + 1}",
        <<~HTML
          <html><head><title>#{article_title}</title></head><body><main>
            #{article_body}
            #{localized_story_rail}
            #{sibling}
          </main></body></html>
        HTML
      )

      expect(result.fetch('markdown')).to include(expected), label if expected
      expect(result.fetch('html')).to include('/map.png'), label if label == 'bare media'
    end
  end

  it 'does not treat one link-heavy analysis owner as repeated rail records' do
    analysis = <<~HTML
      <section class="story-analysis">
        <h2><a href="/analysis/overview">Independent methodology</a></h2>
        <p>The analysis compares <a href="/sources/one">source one</a>, <a href="/sources/two">source two</a>, and <a href="/sources/three">source three</a>.</p>
      </section>
    HTML
    result = fallback_result(
      'https://example.test/news/link-heavy-analysis',
      "<html><head><title>#{article_title}</title></head><body><main>#{article_body}#{localized_story_rail}#{analysis}</main></body></html>"
    )

    expect(result.fetch('markdown')).to include('Independent methodology')
    expect(result.fetch('markdown')).to include('source three')
  end

  it 'does not treat near-match owner class tokens as rail cards' do
    records = Array.new(3) do |index|
      <<~HTML
        <div class="itemized-analysis">
          <h2><a href="/methods/#{index + 1}">Methodology record #{index + 1}</a></h2>
          <p>This independent methodology note explains evidence that must remain visible.</p>
        </div>
      HTML
    end.join
    result = fallback_result(
      'https://example.test/news/methodology',
      "<html><head><title>#{article_title}</title></head><body><main>#{article_body}<section class=stream>#{records}</section></main></body></html>"
    )

    expect(result.fetch('markdown').scan(%r{https://example\.test/methods/\d})).to eq(
      (1..3).map { |number| "https://example.test/methods/#{number}" }
    )
  end

  it 'retains sections, data, figures, references, live updates, and replies owned by the focal article' do
    result = fallback_result(
      'https://example.test/news/owned-article-material',
      <<~HTML
        <html><head><title>Owned article material</title></head><body><main>
          <article>
            <h1>Owned article material</h1>
            <p>The investigation establishes the article boundary with evidence gathered over several months.</p>
            <p>Reporters verified the findings with public records and interviews from affected residents.</p>
            <p>The following material belongs to this article and must remain available to readers.</p>
            <section><h2>Local impact</h2><p>Schools changed their schedules after the river crossed the warning threshold.</p></section>
            <table><tr><th>District</th><th>Level</th></tr><tr><td>North</td><td>High</td></tr></table>
            <figure><img src="/river.jpg" alt="Restored riverbank"><figcaption>The completed riverbank in spring.</figcaption></figure>
            <p>Read the <a href="/records/source-report">supporting source report</a> for the complete measurements.</p>
            <section class="live-updates"><h2>Updates</h2><p><time>12:30</time> Monitoring continued after publication.</p></section>
          </article>
          #{localized_story_rail}
          <section class="comments"><h2>Replies</h2><p>A resident added useful first-hand context after publication.</p></section>
        </main></body></html>
      HTML
    )

    expect(result.fetch('markdown')).to include('Local impact')
    expect(result.fetch('markdown')).to include('North')
    expect(result.fetch('markdown')).to include('The completed riverbank in spring')
    expect(result.fetch('markdown')).to include('supporting source report')
    expect(result.fetch('markdown')).to include('Monitoring continued after publication')
    expect(result.fetch('markdown')).to include('A resident added useful first-hand context')
  end
end
