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
      expect(payload['warnings']).not_to include('truncated_content')
    end
  end
end
