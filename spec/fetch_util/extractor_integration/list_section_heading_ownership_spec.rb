# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor list section heading ownership' do
  include_context 'extractor integration helpers'

  def section_heading_record(number)
    <<~HTML
      <article>
        <h3><a href="/stories/#{number}">Independent newsroom story #{number}</a></h3>
        <p>Locally owned summary for newsroom story #{number}.</p>
      </article>
    HTML
  end

  it 'keeps collection headings through flat coverage without promoting record titles' do
    extra_records = (6..11).map do |number|
      "<li><a href=\"/stories/#{number}\">Independent newsroom story #{number}</a></li>"
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        <section id="lead-record">#{section_heading_record(1)}</section>
        <section id="local-desk">
          <h2><a href="/topics/local">Local desk</a></h2>
          #{section_heading_record(2)}
          #{section_heading_record(3)}
        </section>
        <section id="culture-desk">
          <a href="/topics/culture"><h2>Culture desk</h2></a>
          #{section_heading_record(4)}
          #{section_heading_record(5)}
        </section>
        <ul>#{extra_records}</ul>
      </main></body></html>
    HTML

    with_url_page('https://newsroom.example/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page, reader_mode: false)
      markdown = payload['markdown']
      expected_headings = [
        '## [Local desk](https://newsroom.example/topics/local)',
        '## [Culture desk](https://newsroom.example/topics/culture)'
      ]

      expect(payload['contentType']).to eq('list')
      expect(markdown.scan(/^## .+$/)).to eq(expected_headings)
      expect(markdown.scan('](https://newsroom.example/topics/local)').length).to eq(1)
      expect(markdown.scan('](https://newsroom.example/topics/culture)').length).to eq(1)
      expect(markdown).not_to include('## Independent newsroom story 1')
      story_positions = (1..11).map { |number| markdown.index("/stories/#{number}") }
      expect(story_positions).to eq(story_positions.sort)
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'renders a distinct record alias as a record instead of a section heading' do
    html = <<~HTML
      <html><head><title>Alias newsroom</title></head><body><main>
        <h1>Alias newsroom</h1>
        <section><h2>Local desk</h2>#{section_heading_record(1)}#{section_heading_record(2)}</section>
        <section><h2>Culture desk</h2>#{section_heading_record(3)}#{section_heading_record(4)}</section>
        <section><article><h3><a href="/stories/2">Alternate visible angle on newsroom story 2</a></h3></article></section>
        <ul>
          <li><a href="/stories/5">Independent newsroom story 5</a></li>
          <li><a href="/stories/6">Independent newsroom story 6</a></li>
          <li><a href="/stories/7">Independent newsroom story 7</a></li>
          <li><a href="/stories/8">Independent newsroom story 8</a></li>
          <li><a href="/stories/9">Independent newsroom story 9</a></li>
        </ul>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['markdown']).to include(
        '- [Alternate visible angle on newsroom story 2](https://newsroom.example/stories/2)'
      )
      expect(payload['markdown']).not_to include('## Alternate visible angle on newsroom story 2')
    end
  end

  it 'keeps one-link semantic cards independent from a broader feed owner' do
    sparse_records = (2..10).map do |number|
      metadata = if number == 2
                   ''
                 else
                   <<~HTML
                     <span class="story-category">Desk #{number}</span>
                     <a rel="author" href="/reporters/#{number}">Reporter #{number}</a>
                   HTML
                 end
      <<~HTML
        <article class="StandardCard_standardCard__fixture StandardCard_standardCardStandardLeftFeed__fixture">
          <a class="Common_sectionLink__fixture" href="/stories/#{number}">
            <img src="/images/#{number}.jpg" alt="">
            <h3 class="TitleWrapper_titleWrapper__fixture Common_standardCardTitle__fixture">
              Independent newsroom story #{number}
            </h3>
          </a>
          #{metadata}
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Semantic card newsroom</title></head><body><main>
        <h1>Semantic card newsroom</h1>
        <div class="StandardLeftFeed_StandardLeftFeedItems__fixture">
          #{section_heading_record(1)}
          #{sparse_records}
        </div>
        <section>
          <h2>Local desk</h2>
          #{section_heading_record(11)}
          #{section_heading_record(12)}
        </section>
        <section>
          <h2>Culture desk</h2>
          #{section_heading_record(13)}
          #{section_heading_record(14)}
        </section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      (1..14).each do |number|
        expect(payload['markdown']).to include(
          "- [Independent newsroom story #{number}](https://newsroom.example/stories/#{number})"
        )
      end
      expect(payload['markdown']).not_to include('## Independent newsroom story 2')
      expect(payload['markdown']).not_to match(/^- \[Reporter \d+\]/)
      positions = (1..14).map { |number| payload['markdown'].index("/stories/#{number}") }
      expect(positions).to eq(positions.sort)
    end
  end
end
