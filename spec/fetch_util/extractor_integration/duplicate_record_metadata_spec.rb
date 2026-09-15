# frozen_string_literal: true

RSpec.describe 'FetchUtil duplicate record metadata' do
  include_context 'extractor integration helpers'

  def primary_record(number)
    <<~HTML
      <article class="link-card">
        <a href="/stories/#{number}"><h3>Primary newsroom story #{number}</h3></a>
      </article>
    HTML
  end

  def authored_duplicate(number, author, extra: '')
    slug = author.downcase.tr(' ', '-')
    <<~HTML
      <article class="standard-card">
        <a href="/stories/#{number}"><h3>Primary newsroom story #{number}</h3></a>
        #{extra}
        <span class="byline"><a rel="author" href="/authors/#{slug}">#{author}</a></span>
      </article>
    HTML
  end

  it 'merges only unambiguous locally owned authors from duplicate semantic records' do
    alice = authored_duplicate(1, 'Alice Reporter').sub('</h3></a>', '</h3><span>Breaking</span></a>')
    bob = authored_duplicate(2, 'Bob Reporter')
    carol = authored_duplicate(2, 'Carol Reporter')
    dave = authored_duplicate(3, 'Dave Reporter', extra: '<a href="/sources/wire">Wire source</a>')
    dave_clean = authored_duplicate(3, 'Dave Reporter')
    frank = authored_duplicate(5, 'Frank Reporter').sub('Primary newsroom story 5', 'Different report sharing story 5')
    html = <<~HTML
      <html><head><title>Duplicate record newsroom</title></head><body><main>
        <h1>Duplicate record newsroom</h1>
        <section><h2>Primary desk</h2>#{(1..8).map { |number| primary_record(number) }.join}</section>
        <div class="alternate-layouts">
          #{alice}
          #{bob}
          #{carol}
          #{dave}
          #{dave_clean}
          <article class="standard-card">
            <a href="/stories/4"><h3>Primary newsroom story 4</h3></a>
            <div class="comment-thread"><a rel="author" href="/authors/eve">Eve Commenter</a></div>
          </article>
          #{frank}
          <article class="standard-card">
            <a href="/stories/6"><h3>Primary newsroom story 6</h3></a>
            <span class="byline"><a rel="author" href="/authors/grace">Grace Reporter</a></span>
            <span class="byline"><a rel="author" href="/authors/heidi">Heidi Reporter</a></span>
          </article>
          <table><tr>
            <td><a href="/stories/7"><h5>Primary newsroom story 7</h5></a></td>
            <td><a rel="author" href="/authors/ivan">Ivan Reporter</a></td>
          </tr></table>
          <article class="standard-card">
            <a href="/stories/8"><h3>Primary newsroom story 8</h3></a>
            <span class="byline"><a rel="author" href="/authors/alex-one">Alex Reporter</a></span>
          </article>
          <article class="standard-card">
            <a href="/stories/8"><h3>Primary newsroom story 8</h3></a>
            <span class="byline"><a rel="author" href="/authors/alex-two">Alex Reporter</a></span>
          </article>
        </div>
        <section><h2>Later desk</h2>#{(9..10).map { |number| primary_record(number) }.join}</section>
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/archive', html, reader_mode: false) do |payload|
      story_lines = payload['markdown'].lines.grep(%r{^- .*?/stories/})
      first_story = story_lines.find { |line| line.include?('/stories/1)') }
      seventh_story = story_lines.find { |line| line.include?('/stories/7)') }

      expect(payload['contentType']).to eq('list')
      expect(first_story).to include('[Alice Reporter](https://newsroom.example/authors/alice-reporter)')
      expect(seventh_story).to include('[Ivan Reporter](https://newsroom.example/authors/ivan)')
      expect(story_lines.join).not_to match(/Bob Reporter|Carol Reporter|Dave Reporter|Eve Commenter|Frank Reporter|Grace Reporter|Heidi Reporter|Alex Reporter/)
      story_numbers = story_lines.map { |line| line[%r{/stories/(\d+)}, 1].to_i }
      expect(story_numbers).to eq((1..10).to_a)
    end
  end
end
