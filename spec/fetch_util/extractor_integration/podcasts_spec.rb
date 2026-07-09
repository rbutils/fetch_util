# frozen_string_literal: true

RSpec.describe 'FetchUtil podcast extraction' do
  include_context 'extractor integration helpers'

  it 'classifies PodcastEpisode JSON-LD pages as podcasts and keeps show notes clean' do
    html = fixture_contents(File.expand_path('../../fixtures/podcast_episode_json_ld.html', __dir__))

    extract_from_url('https://podcasts.example.com/episode/obsessive-compulsive-disorder', html) do |payload|
      expect_content_type(payload, 'podcast')
      expect(payload['title']).to eq('Field Notes: Lanterns, Tides, and Quiet Weather')
      expect(payload['markdown']).to include('## Show Notes')
      expect(payload['markdown']).to include('A made-up harbor survey compares brass lantern colors')
      expect(payload['markdown']).to include('## Transcript')
      expect(payload['markdown']).to include('The transcript imagines a bell buoy answering a lantern')
      expect(payload['markdown']).not_to include('About Store Newsletter Episodes')
      expect(payload['markdown']).not_to include('Subscribe to our weekly newsletter')
    end
  end

  it 'prefers the visible episode heading when metadata title is only the site name' do
    html = fixture_contents(File.expand_path('../../fixtures/podcast_episode_lex_title.html', __dir__))

    extract_from_url('https://lexfridman.com/anthony-kaldellis', html) do |payload|
      expect_content_type(payload, 'podcast')
      expect(payload['title']).to eq('Anthony Kaldellis: Byzantine Empire')
      expect(payload['markdown']).to start_with('# Anthony Kaldellis: Byzantine Empire')
      expect(payload['markdown']).to include('[Transcript](https://lexfridman.com/anthony-kaldellis-transcript)')
    end
  end

  it 'promotes an episode heading when a generic article extraction starts with the site name' do
    html = fixture_contents(File.expand_path('../../fixtures/podcast_episode_lex_article_title.html', __dir__))

    extract_from_url('https://lexfridman.com/anthony-kaldellis', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('#498 - Mira Venn: Clockwork Gardens, Paper Moons, and Small Machines')
      expect(payload['markdown']).to start_with('# #498 - Mira Venn: Clockwork Gardens, Paper Moons, and Small Machines')
      expect(payload['markdown']).not_to start_with('# Lex Fridman')
      expect(payload['markdown']).to include('Transcript')
    end
  end

  it 'surfaces transcript links even when generic article extraction wins' do
    html = fixture_contents(File.expand_path('../../fixtures/podcast_episode_transcript_link.html', __dir__))

    extract_from_url('https://www.thisamericanlife.org/890/maximal-americanness', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Maximal Americanness')
      expect(payload['markdown']).to include('## Transcript')
      expect(payload['markdown']).to include('[Transcript](https://www.thisamericanlife.org/890/transcript)')
    end
  end

  it 'classifies a visible podcast show index without JSON-LD' do
    html = <<~HTML
      <html><head><title>Planet Money podcast</title></head><body><main><h1>Planet Money</h1>
        <article class="episode"><h2><a href="/episodes/one">Prices explained</a></h2><time>July 1, 2026</time></article>
        <article class="episode"><h2><a href="/episodes/two">The shipping puzzle</a></h2><time>July 8, 2026</time></article>
        <article class="episode"><h2><a href="/episodes/three">A practical budget</a></h2><time>July 15, 2026</time></article>
      </main></body></html>
    HTML

    extract_from_url('https://podcasts.example.test/podcasts/planet-money', html) do |payload|
      expect_content_type(payload, 'podcast')
      expect(payload['markdown']).to include('[Prices explained](https://podcasts.example.test/episodes/one) - July 1, 2026')
      expect(payload['markdown']).to include('[A practical budget](https://podcasts.example.test/episodes/three) - July 15, 2026')
    end
  end

  it 'keeps podcast words from taking ownership of a credible editorial root' do
    html = fixture_contents(File.expand_path('../../fixtures/credible_editorial_root_podcast_words.html', __dir__))

    extract_from_url('https://editorial.example.test/', html) do |payload|
      expect_content_type(payload, 'list')
      expect(payload['portalRootEvidence']).to eq('namedSectionCount' => 2, 'canonicalCardCount' => 4)
      expect(payload['markdown']).to include('## World', '## Culture and podcasts')
      expect(payload['markdown']).to include('[River agreement opens a new regional corridor](https://editorial.example.test/news/river)')
      expect(payload['markdown']).to include('Editors explain the public record')
      expect(payload['markdown']).to include('[Teachers use public audio in new classroom lessons](https://editorial.example.test/news/education)')
      expect(payload['markdown'].index('River agreement')).to be < payload['markdown'].index('Energy planners')
      expect(payload['markdown'].index('Energy planners')).to be < payload['markdown'].index('Archive project')
      expect(payload['markdown'].index('Archive project')).to be < payload['markdown'].index('Teachers use')
      expect(payload['contentType']).not_to eq('podcast')
    end
  end

  it 'does not classify an article that merely mentions podcasts' do
    html = <<~HTML
      <html><head><title>Podcast history</title></head><body><main><h1>Podcast history</h1>
      <p>This article mentions podcasts and episodes but has no show entries.</p></main></body></html>
    HTML

    extract_from_url('https://example.test/history', html) do |payload|
      expect(payload['contentType']).not_to eq('podcast')
    end
  end
end
