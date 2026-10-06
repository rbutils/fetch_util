# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration - trope wiki pages' do
  include_context 'extractor integration helpers'

  it 'extracts full trope example lists instead of only the intro stub' do
    examples = (1..24).map do |index|
      <<~HTML
        <li>
          <a class="twikilink" href="/pmwiki/pmwiki.php/Main/TropeExample#{index}">Trope Example #{index}</a>:
          Shawshank example #{index} explains how Andy and Red carry the film's prison drama forward with a concrete story beat.
        </li>
      HTML
    end.join

    html = <<~HTML
      <html>
        <head><title>The Shawshank Redemption (Film) - TV Tropes</title></head>
        <body>
          <div id="main-content">
            <article id="main-article">
              <h1>Film / The Shawshank Redemption</h1>
              <div class="article-content retro-folders">
                <div id="modal_overlay">WHERE TO WATCH Stream Rent Buy</div>
                <p>The Shawshank Redemption is a 1994 drama film directed by Frank Darabont.</p>
                <div class="folderlabel">This film provides examples of:</div>
                <ul>
                  #{examples}
                </ul>
              </div>
            </article>
          </div>
        </body>
      </html>
    HTML

    with_url_page('https://tvtropes.org/pmwiki/pmwiki.php/Film/TheShawshankRedemption', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Trope Example 24')
      expect(payload['markdown']).to include("Shawshank example 24 explains how Andy and Red carry the film's prison drama forward")
      offsets = (1..24).map do |index|
        destination = "https://tvtropes.org/pmwiki/pmwiki.php/Main/TropeExample#{index}"
        expect(payload['markdown']).to include("[Trope Example #{index}](#{destination})")
        payload['markdown'].index(destination)
      end
      expect(offsets).to eq(offsets.sort)
      expect(payload['markdown']).not_to include('WHERE TO WATCH')
      expect(payload['warnings']).not_to include('truncated_content')
    end
  end

  it 'removes source-proven availability controls without removing authored modal content' do
    html = <<~HTML
      <html><head><title>Independent film notes</title></head><body>
        <article id="film-notes"><h1>Independent film notes</h1>
          <div id="availability" class="modal-overlay">WHERE TO WATCH Stream Rent Buy</div>
          <p>These authored film notes explain the story, characters and production decisions in useful detail.</p>
          <p>A second authored paragraph discusses the narrative and preserves the relevant context for readers.</p>
          <div class="modal-overlay"><p>Authored analysis explains why people stream, rent or buy films without being a control.</p></div>
          <div class="modal-overlay"><a href="/research">Stream Rent Buy research</a></div>
          <div class="modal-overlay"><pre>Stream Rent Buy</pre></div>
        </article>
      </body></html>
    HTML
    with_url_page('https://film-notes.example/analysis/independent', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).not_to include('WHERE TO WATCH')
      expect(payload['markdown']).to include('Authored analysis explains why people stream, rent or buy films')
      expect(payload['markdown']).to include('[Stream Rent Buy research](https://film-notes.example/research)')
      expect(payload['markdown']).to include('Stream Rent Buy')
    end
  end
end
