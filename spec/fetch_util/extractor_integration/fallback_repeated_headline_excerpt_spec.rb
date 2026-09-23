# frozen_string_literal: true

RSpec.describe 'FetchUtil fallback excerpts with repeated external headlines' do
  include_context 'extractor integration helpers'

  let(:short_title) { 'Researchers publish complete regional transport funding records' }
  let(:headline) { "#{short_title}, including independently checked evidence from every district" }
  let(:paragraphs) do
    [
      'The first substantive paragraph explains the published transport decisions and their independently verified measurements for each district.',
      'The next paragraph identifies the public funding sources, the consultation dates, and the timetable for residents following this programme.',
      'The final paragraph documents the source records so readers can inspect the consultation and the supporting measurements themselves.'
    ]
  end

  def repeated_headline_source
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, 'websieve', entry))
    end.join("\n")
    source.sub('})(window);', 'global.repeatedHeadlineProbe = fallbackRepeatedHeadlineExcerpt; })(window);')
  end

  it 'uses source-owned body prose rather than repeating the already reported headline' do
    article = ([headline] + paragraphs).map { |text| "<p>#{text}</p>" }.join
    html = <<~HTML
      <html><head><title>#{short_title} | Public records journal</title>
      <meta property="og:site_name" content="Public records journal"></head><body><main>
        <h1>#{headline}</h1><div class="article-author">Independent author</div>
        <aside><a href="/reports/other">An independent report on another subject</a>
          <a href="/reports/archive">Browse the complete public archive</a></aside>
        <article class="article fmt article-content">#{article}</article>
      </main></body></html>
    HTML

    with_url_page('https://records.example/articles/regional-funding', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['title']).to eq(headline)
      paragraphs.each { |text| expect(payload['markdown']).to include(text) }
      expect(payload['markdown']).to include(headline)
      page.add_script_tag(content: repeated_headline_source)
      excerpt = page.evaluate(<<~JS)
        repeatedHeadlineProbe(document.querySelector('main article'), document.querySelector('main article').textContent,
          {siteName: 'Public records journal'})
      JS
      expect(excerpt).to start_with('The first substantive paragraph')
      expect(excerpt).to include('The next paragraph identifies')
      expect(excerpt).not_to include(headline, 'Public records journal')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps the original excerpt when the source owner is ambiguous' do
    html = <<~HTML
      <html><head><title>#{short_title} | Public records journal</title></head><body><main>
        <h1>#{headline}</h1>
        <article>#{([headline] + paragraphs).map { |text| "<p>#{text}</p>" }.join}</article>
        <article><p>A separate editorial article with a different owner appears on the same page.</p></article>
      </main></body></html>
    HTML

    with_url_page('https://records.example/articles/regional-funding', html) do |page|
      page.add_script_tag(content: repeated_headline_source)

      expect(page.evaluate(<<~JS)).to be_nil
        repeatedHeadlineProbe(document.querySelector('main article'), document.querySelector('main article').textContent,
          {siteName: 'Public records journal'})
      JS
    end
  end
end
