require 'spec_helper'
require 'nokogiri'

RSpec.describe 'FetchUtil dated table record ownership' do
  include_context 'extractor integration helpers'

  it 'retains each self-contained dated row without borrowing the next title as its author' do
    titles = ['Today in river restoration', 'Surveying the old woodland', 'Measuring coastal change',
              'A practical restoration handbook', 'The final field observation']
    rows = titles.each_with_index.map do |title, index|
      "<tr><td><a href='/reference/#{index}'>#{title}</a></td><td>#{index + 1} days ago</td></tr>"
    end.join
    html = <<~HTML
      <html><head><title>Field reference discoveries</title></head><body>
      <nav><a href='/tools'>Tools and templates</a></nav><main><h1>Field reference discoveries</h1>
      <p>Explore these newly published reference entries, each with its own title and publication age.</p>
      <table><tbody>#{rows}</tbody></table></main></body></html>
    HTML

    extract_from_url('https://references.test/', html) do |payload|
      markdown = payload['markdown']
      expect(payload['contentType']).to eq('social')
      expect(Nokogiri::HTML5.fragment(payload['html']).css('table tbody tr').length).to eq(titles.length)
      positions = titles.each_with_index.map do |title, index|
        expect(markdown).to include("[#{title}](https://references.test/reference/#{index})")
        expect(markdown).to include("#{index + 1} days ago")
        expect(markdown).not_to include("by #{title}")
        markdown.index("[#{title}](")
      end
      expect(positions).to eq(positions.sort)
    end
  end

  it 'keeps real alternating title and attribution rows even when a title contains a relative-date word' do
    rows = 4.times.map do |index|
      <<~HTML
        <tr><td><a href='/story/#{index}'>Today in restoration research #{index}</a></td></tr>
        <tr><td><a rel='author' href='/people/writer-#{index}'>Writer #{index}</a>
        <time datetime='2026-10-10T10:00:00Z'>#{index + 1} hours ago</time> #{index + 10} points</td></tr>
      HTML
    end.join
    html = "<html><head><title>Research submissions</title></head><body><main><h1>Research submissions</h1><table>#{rows}</table></main></body></html>"

    extract_from_url('https://discussion.test/', html) do |payload|
      4.times do |index|
        expect(payload['markdown']).to include("[Today in restoration research #{index}](https://discussion.test/story/#{index})")
        expect(payload['markdown']).to include("by Writer #{index}")
      end
    end
  end

  it 'does not turn one dated reference inside reporting into a publication feed' do
    paragraphs = 5.times.map { |index| "<p>Observation #{index} explains the documented restoration methods and their practical field implications in detail.</p>" }.join
    html = <<~HTML
      <html><head><title>Restoration field report</title></head><body><main><article>
      <h1>Restoration field report</h1>#{paragraphs}
      <table><tr><td><a href='/reference'>The supporting observation</a></td><td>1 day ago</td></tr></table>
      </article></main></body></html>
    HTML

    extract_from_url('https://reporting.test/field-report', html) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('Observation 4', 'The supporting observation')
    end
  end

  it 'keeps unmarked paired attribution out of standalone records while retaining nested replies' do
    html = fixture_contents(File.expand_path('../../fixtures/table_social_nested_layout.html', __dir__))
    extract_from_url('https://forum.example.test/discussion/7', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'handle' => 'mira', 'replyCount' => 1)
      expect(payload['markdown']).to include('shares its table', '`source_code`', 'supporting reference',
                                             'Owned field', 'Research value', 'Noah', 'The nested reply preserves its full source.')
      expect(payload['html']).to include('https://docs.example.test/nested', 'The nested reply preserves its full source.')
    end
  end
end
