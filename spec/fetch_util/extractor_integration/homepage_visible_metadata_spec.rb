# frozen_string_literal: true

RSpec.describe 'FetchUtil homepage visible metadata' do
  include_context 'extractor integration helpers'

  it 'keeps story-card authors local on a root homepage list' do
    cards = (1..8).map do |number|
      <<~HTML
        <article>
          <h2><a href="/stories/#{number}">Independent homepage report #{number}</a></h2>
          <a rel="author" href="/authors/#{number}">Reporter #{number}</a>
          <p>Locally owned summary for independent homepage report #{number}.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        #{cards}
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['byline']).to be_nil
      expect(payload['markdown']).to include('[Reporter 1](https://newsroom.example/authors/1)')
    end
  end

  it 'keeps a visible byline on one focal article at a root route' do
    prose = ('A focused homepage essay provides substantial reporting analysis. ' * 12).strip
    html = <<~HTML
      <html><head><title>Focused homepage essay</title></head><body><main>
        <article role="main">
          <h1>Focused homepage essay</h1>
          <a rel="author" href="/authors/editor">Homepage Essayist</a>
          <p>#{prose}</p>
        </article>
      </main></body></html>
    HTML

    extract_from_url('https://essay.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['byline']).to eq('Homepage Essayist')
    end
  end

  it 'does not promote localized author-profile links from a multi-story homepage' do
    cards = (1..4).map do |number|
      <<~HTML
        <article>
          <h2><a href="/stories/#{number}">Independent homepage report #{number}</a></h2>
          <a href="/autoren/reporter-#{number}">Reporter #{number}</a>
          <p>Locally owned summary for independent homepage report #{number}.</p>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Independent newsroom</title></head><body><main>
        <h1>Independent newsroom</h1>
        #{cards}
      </main></body></html>
    HTML

    extract_from_url('https://newsroom.example/', html, reader_mode: false) do |payload|
      expect(payload['contentType']).to eq('list')
      expect(payload['byline']).to be_nil
    end
  end
end
