# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - Hacker News' do
  include_context 'extractor integration helpers'

  def hacker_news_fixture(name)
    fixture_contents(File.expand_path("../../../../fixtures/#{name}", __dir__))
  end

  it 'extracts item threads with story text, source links, and nested comments' do
    extract_from_url('https://news.ycombinator.com/item?id=100', hacker_news_fixture('hacker_news_item_thread.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Hacker News',
                                 'handle' => 'alice', 'score' => 42, 'replyCount' => 2, 'community' => nil)
      expect(payload['markdown']).to include('[Sample parser note](https://example.test/parser)')
      expect(payload['markdown']).to include('Fixture text keeps `code` intact.')
      expect(payload['markdown']).to include('### bob (2 hours ago)')
      expect(payload['markdown']).to include('#### carol (1 hour ago)')
    end
  end

  it 'keeps comment-only and deleted item pages as social posts' do
    extract_from_url('https://news.ycombinator.com/item?id=101', hacker_news_fixture('hacker_news_comment_deleted.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'post', 'platform' => 'Hacker News',
                                 'handle' => 'dave', 'replyCount' => nil, 'score' => nil)
      expect(payload['markdown']).to include('Comment content is retained.')
      expect(payload['markdown']).to include('### Deleted comment')
      expect(payload['markdown']).to include('[deleted]')
    end
  end

  it 'extracts signed-out section feeds only when multiple HN story rows exist' do
    extract_from_url('https://news.ycombinator.com/ask', hacker_news_fixture('hacker_news_feed.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Hacker News',
                                 'community' => 'Ask HN')
      expect(payload['markdown']).to include('[Ask HN: How do you document small systems?](https://example.test/docs)')
      expect(payload['markdown']).to include('18 points - by erin')
      expect(payload['html']).to include('<tr class="athing"', '<td>')
    end
  end

  it 'extracts the native homepage table as a social feed' do
    extract_from_url('https://news.ycombinator.com/', hacker_news_fixture('hacker_news_homepage.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Hacker News')
      expect(payload['markdown']).to include('[A homepage story](https://example.test/homepage)')
      expect(payload['html']).to include('<tr class="athing"', '<td>')
    end
  end

  it 'does not classify a hostname-only lookalike as social' do
    extract_from_url('https://news.ycombinator.com/item?id=102', hacker_news_fixture('hacker_news_lookalike.html')) do |payload|
      expect(payload['contentType']).not_to eq('social')
      expect(payload['platform']).to be_nil
    end
  end

  it 'does not classify a generic item table on another host as social' do
    extract_from_url('https://example.test/', hacker_news_fixture('hacker_news_generic_table.html')) do |payload|
      expect(payload['contentType']).not_to eq('social')
      expect(payload['platform']).to be_nil
    end
  end

  it 'extracts unknown-host discussions with linked authors, code, nested replies and deleted markers' do
    extract_from_url('https://forum.example.test/discussion/42', hacker_news_fixture('table_social_unknown_thread.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Atlas Forum',
                                 'handle' => 'mira', 'score' => 73, 'replyCount' => 2)
      expect(payload['markdown']).to include('Source text retains `small code`',
                                             '[reference link](https://docs.example.test/guide)',
                                             '[a source link](https://reply.example.test/one)',
                                             '#### Pia (2 hours ago)', 'puts :kept', 'Deleted comment', '[deleted]')
      expect(payload['html']).to include('First reply', 'Nested response')
    end
  end

  it 'retains all unknown-host feed records and source community metadata in order' do
    extract_from_url('https://commons.example.test/front', hacker_news_fixture('table_social_unknown_feed.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Example Commons',
                                 'community' => 'Community front page')
      positions = %w[First Second Third].map { |word| payload['markdown'].index("#{word} community item") }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(payload['markdown']).to include('31 points', '22 points', '9 points', '4 replies', '3 replies', '1 replies')
    end
  end

  it 'keeps scoreless job rows and zero-score dead records on an unrelated host' do
    extract_from_url('https://commons.example.test/jobs', hacker_news_fixture('table_social_jobs_and_dead.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'platform' => 'Example Commons',
                                 'community' => 'Community jobs')
      labels = ['Field Engineer', 'Senior Researcher', '\\[dead\\] Research assistant']
      positions = labels.map { |label| payload['markdown'].index(label) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(payload['markdown']).to include('by lee', '0 points', '4 hours ago')
      expect(payload['markdown']).not_to include('null points', 'by null')
    end
  end

  it 'preserves story bodies and comments inside nested layout tables' do
    extract_from_url('https://forum.example.test/discussion/7', hacker_news_fixture('table_social_nested_layout.html')) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'handle' => 'mira', 'replyCount' => 1)
      expect(payload['markdown']).to include('shares its table', '`source_code`',
                                             '[supporting reference](https://docs.example.test/nested)',
                                             'Owned field', 'Research value', '42', 'Noah',
                                             'The nested reply preserves its full source.')
      expect(payload['html']).to include('source_code', 'Research value', 'The nested reply preserves its full source.')
    end
  end

  it 'does not promote hidden tables or authored article tables to social content' do
    %w[table_social_hidden.html table_social_authored_article.html].each do |fixture|
      extract_from_url('https://forum.example.test/', hacker_news_fixture(fixture)) do |payload|
        expect(payload['contentType']).not_to eq('social')
      end
    end
    quoted = hacker_news_fixture('table_social_unknown_feed.html').sub('<table>', '<blockquote><table>').sub('</table>', '</table></blockquote>')
    extract_from_url('https://forum.example.test/analysis', quoted) do |payload|
      expect(payload['contentType']).not_to eq('social')
    end
  end

  it 'retains short story titles beside source-domain links without inventing comments from ordinary rows' do
    html = <<~HTML
      <html><head><title>Source feed | Example Forum</title></head><body><table>
        <tr><td><a href="https://go.example.test/start">Go</a> <a href="/source/go.example.test">(go.example.test)</a></td></tr>
        <tr><td>5 points by <a rel="author">maya</a> <time datetime="2026-10-08">Today</time></td></tr>
        <tr><td><a href="https://r.example.test/start">R</a></td></tr>
        <tr><td>3 votes by <a rel="author">lee</a> <time datetime="2026-10-07">Yesterday</time></td></tr>
      </table></body></html>
    HTML
    extract_from_url('https://forum.example.test/front', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'replyCount' => nil)
      expect(payload['markdown']).to include('[Go](https://go.example.test/start)', '[R](https://r.example.test/start)')
      expect(payload['html']).to include('/source/go.example.test')
    end
  end

  it 'retains short and image-only comments, nested body tables and every visible reply' do
    rows = (1..75).map do |number|
      body = case number
             when 1 then '<p>OK</p>'
             when 2 then '<p>是</p><div><table><tr><td>Authored cell</td></tr></table></div>'
             when 3 then '<img src="https://media.example.test/reply.png" alt="Source reply image">'
             when 4 then '<span itemprop="text">Reply</span>'
             when 5 then '<p>A dated parent does not require this reply to repeat its timestamp.</p>'
             else "<p>Published reply #{number}</p>"
             end
      time = number == 5 ? '' : "<time datetime='2026-10-08'>1 hour ago</time>"
      "<tr data-depth='#{number == 2 ? 2 : 0}'><td></td><td><a rel='author'>writer#{number}</a>" \
        "#{time}#{body}</td></tr>"
    end.join
    html = "<html><head><title>Discussion | Example Forum</title></head><body><table>#{rows}</table></body></html>"

    extract_from_url('https://forum.example.test/discussion', html) do |payload|
      expect(payload['contentType']).to eq('social')
      expect(payload['markdown']).to include('OK', '是', 'Authored cell', 'https://media.example.test/reply.png',
                                             '##### writer2 (1 hour ago)', "writer4 (1 hour ago)\n\nReply", 'Published reply 75',
                                             "### writer5\n\nA dated parent")
      positions = (1..75).map do |number|
        suffix = number == 5 ? "\n" : ' (1 hour ago)'
        payload['markdown'].index("writer#{number}#{suffix}")
      end
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
    end
  end
end
