# frozen_string_literal: true

RSpec.describe 'FetchUtil Hindustan Times extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts complete Hindustan Times articles through shared reader handling' do
    url = 'https://www.hindustantimes.com/opinion/hindi-and-its-role-in-the-unified-future-of-india-101726241382225.html'
    html = fixture_contents(File.expand_path('../../fixtures/hindustantimes_article.html', __dir__))

    with_url_page(url, html) do |page|
      document_without_scripts = <<~JS
        (() => {
          const clone = document.documentElement.cloneNode(true);
          clone.querySelectorAll("head script").forEach((script) => script.remove());
          return clone.outerHTML;
        })()
      JS
      before = page.evaluate(document_without_scripts)
      payload = extract_payload(page)

      expect(payload['markdown']).to eq(<<~MARKDOWN.chomp)
        # Hindi, and its role in the unified future of India

        By Girish Nath Jha

        Updated on: Sep 13, 2024, 20:59:42 IST

        Sep 13, 2024

        Hindi Divas (Hindi Day), observed every year on September 14, calls for a reflection on the language’s journey from adoption as the official language of the Union in 1949 to what it is today and what it is going to be tomorrow.

        ![Hindi has been a popular language in the digital world (HT Archive)](https://www.hindustantimes.com/ht-img/img/2024/09/13/400x225/Hindi-has-been-a-popular-language-in-the-digital-w_1726241378232.jpg)

        Hindi has been a popular language in the digital world (HT Archive)

        Today, Hindi has the fourth-largest speech community in the world. It is commonly spoken in ten states and three Union Territories.

        This journey has not been without problems. In a culturally and linguistically diverse country, arriving at a consensus is not always easy.

        The Constituent Assembly showed remarkable vision in adopting Hindi with the Devanagari script as the official language of the Union.

        The forward march of Hindi has been impressive. It has to continue progressing with inclusiveness so that it is truly sarva samaveshi, for the unified and inclusive future of India.
      MARKDOWN
      expect(payload['html']).to include(
        '<figcaption>Hindi has been a popular language in the digital world (HT Archive)</figcaption>',
        '<time datetime="2024-09-13T20:59:42+05:30">Sep 13, 2024</time>'
      )
      expect(payload).to include(
        'title' => 'Hindi, and its role in the unified future of India',
        'byline' => 'Girish Nath Jha',
        'publishedTime' => '2024-09-13T20:59:42+05:30',
        'contentType' => 'article',
        'readerMode' => true,
        'hostAware' => false,
        'warnings' => ['stale_content'],
        'suspect' => true
      )
      expect(page.evaluate(document_without_scripts)).to eq(before)
    end
  end

  it 'leaves Hindustan Times homepages to shared list extraction' do
    cards = (1..6).map do |index|
      <<~HTML
        <article>
          <a href="https://www.hindustantimes.com/india-news/story-#{index}.html">
            <h2>Hindustan Times homepage story #{index}</h2>
          </a>
        </article>
      HTML
    end.join

    with_url_page('https://www.hindustantimes.com/', "<main><h1>Hindustan Times</h1>#{cards}</main>") do |page|
      payload = extract_payload(page, reader_mode: false)
      markdown = payload.fetch('markdown')

      expect(payload).to include('contentType' => 'list', 'hostAware' => false)
      story_positions = (1..6).map do |index|
        markdown.index(
          "[Hindustan Times homepage story #{index}](https://www.hindustantimes.com/india-news/story-#{index}.html)"
        )
      end
      expect(story_positions).to all(be_a(Integer))
      expect(story_positions).to eq(story_positions.sort)
    end
  end
end
