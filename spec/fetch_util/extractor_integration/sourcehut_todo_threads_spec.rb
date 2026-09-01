# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

RSpec.describe 'FetchUtil extractor integration - SourceHut todo threads' do
  include_context 'extractor integration helpers'

  def sourcehut_todo_fixture
    fixture_contents(File.expand_path('../fixtures/sourcehut_todo_ticket.html', __dir__))
  end

  it 'preserves a host-agnostic SourceHut ticket conversation and traversal inventory' do
    extract_from_url('https://forge.example.test/~alice/tracker/42', sourcehut_todo_fixture, reader_mode: false) do |payload|
      markdown = payload.fetch('markdown')
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'SourceHut',
                                 'handle' => '~alice', 'replyCount' => nil, 'community' => '~alice/tracker',
                                 'publishedTime' => nil)
      expect(markdown).to include('# Preserve ticket history', 'Opening SourceHut ticket body.',
                                  'Restored opening detail.',
                                  '[Comment by ~bob](https://forge.example.test/~alice/tracker/42#event-101)',
                                  'First SourceHut comment.',
                                  '[Event by ~meta-user](https://forge.example.test/~alice/tracker/42#event-102)',
                                  'added triage',
                                  '[Event by ~resolver](https://forge.example.test/~alice/tracker/42#event-103)',
                                  'RESOLVED DUPLICATE', 'assigned ~assignee', 'Restored SourceHut comment.',
                                  '## Metadata', 'OPEN', 'No-one',
                                  '[Tracker](https://forge.example.test/~alice/tracker)',
                                  '[Source repository](https://git.example.test/~alice/project)',
                                  'Email comments: `mailto:~alice/tracker/42@todo.sr.ht?subject=Comment`')
      expect(markdown).to include('- Time: 2025-01-02 03:04:05 UTC')
      expect(markdown).not_to include('Email comments: `mailto:~alice/tracker@todo.sr.ht')
      expect(markdown.scan('Repeated idless SourceHut event.').length).to eq(2)
      expect(markdown.scan('First SourceHut comment.').length).to eq(1)
      expect(markdown.scan('added triage').length).to eq(1)
      expect(markdown.scan('RESOLVED DUPLICATE').length).to eq(1)
      expect(payload.fetch('excerpt')).not_to include('Hidden opening text', '.highlight')
      expect(markdown).not_to include('Hidden opening text', 'Hidden SourceHut event.',
                                      'Duplicate stable event must not render', '.highlight {')
      expect(payload.fetch('html')).not_to include('<style', 'Hidden SourceHut event.')
      expect(markdown.index('First SourceHut comment.')).to be < markdown.index('added triage')
      expect(markdown.index('added triage')).to be < markdown.index('Restored SourceHut comment.')
    end
  end

  it 'preserves an uncapped SourceHut timeline in DOM order' do
    records = (1..25).map do |index|
      <<~HTML
        <div class="event"><h4 id="event-#{200 + index}"><a href="/~user#{index}">~user#{index}</a> commented <a href="#event-#{200 + index}">recently</a></h4>
          <blockquote><p>Uncapped SourceHut comment #{index}.</p></blockquote></div>
      HTML
    end.join
    html = sourcehut_todo_fixture.sub('<!-- bulk-events -->', records)

    extract_from_url('https://forge.example.test/~alice/tracker/42', html, reader_mode: false) do |payload|
      found = payload.fetch('markdown').scan(/Uncapped SourceHut comment (\d+)\./).flatten.map(&:to_i)
      expect(found).to eq((1..25).to_a)
    end
  end

  it 'supports arbitrary domains without hostname ownership' do
    extract_from_url('https://tickets.example.test/~alice/tracker/42', sourcehut_todo_fixture, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'SourceHut', 'community' => '~alice/tracker')
      expect(payload.fetch('markdown')).to include('https://tickets.example.test/~alice/tracker/42#event-101')
    end
  end

  it 'does not fabricate a publication time from relative ticket text' do
    extract_from_url('https://forge.example.test/~alice/tracker/42', sourcehut_todo_fixture, reader_mode: false) do |payload|
      expect(payload).to include('platform' => 'SourceHut', 'publishedTime' => nil)
    end
  end

  it 'keeps valid tickets when the optional opening description is absent' do
    document = Nokogiri::HTML(sourcehut_todo_fixture)
    document.at_css('#description-field').remove

    extract_from_url('https://forge.example.test/~alice/tracker/42', document.to_html, reader_mode: false) do |payload|
      expect(payload).to include('contentType' => 'social', 'platform' => 'SourceHut')
      expect(payload.fetch('markdown')).to include('First SourceHut comment.', '## Timeline')
    end
  end

  it 'requires independent SourceHut todo product evidence and matching ticket identity' do
    without_asset = sourcehut_todo_fixture.gsub(%r{\s*<link rel="stylesheet" href="/static/todo\.sr\.ht/[^"]+">}, '')
    off_origin_asset = sourcehut_todo_fixture.sub('href="/static/', 'href="https://lookalike.invalid/static/')
    off_origin_navigation = sourcehut_todo_fixture.gsub('href="/~alice/tracker', 'href="https://lookalike.invalid/~alice/tracker')
    wrong_identity = sourcehut_todo_fixture.sub('<span class="ticket-id">#42</span>', '<span class="ticket-id">#43</span>')
    without_events = sourcehut_todo_fixture.sub('class="event-list ticket-events"', 'class="event-list-lookalike"')

    { without_asset: without_asset, off_origin_asset: off_origin_asset,
      off_origin_navigation: off_origin_navigation, wrong_identity: wrong_identity,
      without_events: without_events }.each do |name, html|
      aggregate_failures(name) do
        extract_from_url('https://forge.example.test/~alice/tracker/42', html, reader_mode: false) do |payload|
          expect(payload['platform']).not_to eq('SourceHut')
        end
      end
    end
  end

  it 'keeps malformed and non-ticket routes outside SourceHut todo extraction' do
    ['https://forge.example.test/~alice/tracker',
     'https://forge.example.test/~alice/tracker/not-a-number',
     'https://forge.example.test/~alice//tracker/42',
     'https://forge.example.test//~alice/tracker/42'].each do |url|
      extract_from_url(url, sourcehut_todo_fixture, reader_mode: false) do |payload|
        expect(payload['platform']).not_to eq('SourceHut')
      end
    end
  end
end
