# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'Source-owned published feed' do
  include_context 'extractor integration helpers'

  def extract_document(url, html)
    with_url_page(url, html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      @source_article_count = page.evaluate("document.querySelectorAll('article').length")
      payload
    end
  end

  def published_entry(index, dated: true, linked: true, body: nil)
    title = linked ? "<h2><a href='/destination/shared'>Public entry #{index}</a></h2>" : ''
    time = dated ? "<time datetime='2026-10-10T08:#{format("%02d", index)}:00Z'>Published entry #{index}</time>" : ''
    <<~HTML
      <section id='entry-#{index}'><aside class='vote-panel'><p>#{100 + index}</p><button>Vote</button></aside>
      <article><header>#{title}<a class='username' href='/contributors/writer-#{index}'>Writer #{index}</a>#{time}</header>
      #{body || "<p>Authored reporting #{index}, with distinct complete context.</p>"}</article></section>
    HTML
  end

  def feed_document(entries, extra: '')
    "<!doctype html><html><head><title>Public discussions</title></head><body><main><header><h1>Public discussions</h1><p>Latest</p></header>" \
      "<div role='feed'>#{entries}#{extra}</div><figure class='age-filter'><p><span>Show 18+</span></p></figure></main></body></html>"
  end

  it 'retains every ordered entry with duplicate destinations, undated publication and short unlinked material' do
    entries = (1..36).map { |index| published_entry(index) }.join
    entries += published_entry(37, dated: false, body: '<p>Authored sponsored research.</p>')
    material = '<p>OK</p><pre><code>answer = 42</code></pre><blockquote>Show 18+</blockquote>' \
               '<figure class="age-filter"><figcaption><p>Authored explanation of Show 18+ accessibility.</p></figcaption></figure>' \
               '<img src="https://media.example.test/chart.png" alt="Published chart">'
    entries += published_entry(38, linked: false, body: material)
    extra = <<~HTML
      <article><h2><a href='/join'>Register for updates</a></h2><p>Create an account to participate.</p></article>
      <article><h2><a href='/offer'>Special promotional offer</a></h2><p>Buy an account package today.</p></article>
      <section hidden>#{published_entry(39)}</section>
    HTML
    payload = extract_document('https://discussion.example.test/', feed_document(entries, extra: extra))
    selected = Nokogiri::HTML5.fragment(payload.fetch('html'))

    expect(payload.fetch('contentType')).to eq('social')
    expect(payload.fetch('socialKind')).to eq('feed')
    expect(payload.fetch('contentFormat')).to be_nil
    expect(payload.fetch('warnings')).not_to include('multi_topic_page')
    expect(selected.css('article').length).to eq(38)
    expect(selected.css('h2').map(&:text)).to eq((1..37).map { |index| "Public entry #{index}" })
    expect(selected.css('a.username').map(&:text)).to eq((1..38).map { |index| "Writer #{index}" })
    expect(selected.css('time').length).to eq(37)
    expect(payload.fetch('markdown')).to include(
      'Authored sponsored research.', 'OK', 'answer = 42', 'Show 18+',
      'Authored explanation of Show 18+ accessibility.', 'https://media.example.test/chart.png'
    )
    expect(payload.fetch('markdown')).not_to include('Register for updates', 'Special promotional offer', 'Public entry 39')
    expect(@source_article_count).to eq(41)
  end

  it 'preserves a competing focal article and its actual discussion instead of selecting a feed' do
    reporting = (1..8).map { |index| "<p>Focal reporting #{index} explains the investigation and its primary source evidence.</p>" }.join
    html = <<~HTML
      <!doctype html><html><head><title>Primary investigation</title></head><body><main>
      <article><h1>Primary investigation</h1>#{reporting}<section>#{(1..4).map { |index| published_entry(index) }.join}</section></article>
      </main></body></html>
    HTML
    payload = extract_document('https://reporting.example.test/investigation', html)

    expect(payload.fetch('socialKind')).not_to eq('feed')
    (1..8).each { |index| expect(payload.fetch('markdown')).to include("Focal reporting #{index}") }
  end

  it 'does not infer published ownership from quoted metadata or control-only registration records' do
    quoted = (1..4).map do |index|
      "<article><h2><a href='/reference/#{index}'>Quoted reference #{index}</a></h2><blockquote>" \
        "<a class='username' href='/contributors/quoted'>Quoted writer</a><time datetime='2026-10-10'>Published</time>" \
        "<span data-score='123'>123</span></blockquote><p>Actual catalogue description #{index}.</p></article>"
    end.join
    payload = extract_document('https://catalogue.example.test/', feed_document(quoted))

    expect(payload.fetch('socialKind')).not_to eq('feed')
    (1..4).each { |index| expect(payload.fetch('markdown')).to include("Actual catalogue description #{index}.") }
  end

  it 'does not replace primary material outside the publication collection' do
    entries = (1..4).map { |index| published_entry(index) }.join
    html = feed_document(entries).sub('<div role=', '<section><p>Independent authored guidance outside all publication records must remain.</p></section><div role=')
    payload = extract_document('https://guidance.example.test/', html)

    expect(payload.fetch('socialKind')).not_to eq('feed')
    expect(payload.fetch('markdown')).to include('Independent authored guidance outside all publication records must remain.')
  end

  it 'preserves explicitly declared live reporting rather than overriding it with a publication feed' do
    entries = (1..8).map { |index| published_entry(index) }.join
    declaration = '<script type="application/ld+json">{"@context":"https://schema.org","@type":"LiveBlogPosting",' \
                  '"headline":"Public discussions","url":"https://updates.example.test/"}</script>'
    payload = extract_document('https://updates.example.test/', feed_document(entries).sub('</head>', "#{declaration}</head>"))

    expect(payload.fetch('socialKind')).not_to eq('feed')
    expect(payload.fetch('contentFormat')).to eq('liveblog')
    (1..8).each { |index| expect(payload.fetch('markdown')).to include("Authored reporting #{index}") }
  end
end
