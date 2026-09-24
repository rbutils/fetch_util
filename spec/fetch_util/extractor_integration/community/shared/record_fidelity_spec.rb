# frozen_string_literal: true

RSpec.describe 'FetchUtil community record fidelity' do
  include_context 'extractor integration helpers'

  def repeated_nodes(wrapper, count)
    (1..count).map { |index| format(wrapper, index: index) }.join
  end

  it 'preserves every Reddit comment, including comments after the former cap' do
    comments = repeated_nodes(<<~HTML, 10)
      <shreddit-comment depth="0" author="user%<index>d" score="%<index>d">
        <div slot="comment">Reddit comment %<index>d is visible.</div>
      </shreddit-comment>
    HTML
    html = <<~HTML
      <shreddit-post author="alice" comment-count="10" score="17">
        <h1 slot="title">Ruby thread</h1><div slot="text-body">A public Reddit post.</div>
      </shreddit-post>
      #{comments}
    HTML

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/ruby-thread', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Reddit')
      expect(payload['markdown']).to include('Reddit comment 1 is visible.', 'Reddit comment 10 is visible.')
      expect(payload['markdown'].index('Reddit comment 1')).to be < payload['markdown'].index('Reddit comment 10')
    end
  end

  it 'preserves every visible subreddit post despite optional media differences' do
    posts = (1..27).map do |index|
      title = format('Visible subreddit post %02d', index)
      author = format('author%02d', index)
      slug = format('%02d', index)
      media = index == 27 ? '<img src="/images/final-post.jpg" alt="Final post image">' : ''
      <<~HTML
        <article>
          <shreddit-post author="#{author}" score="#{index}">
            <a href="/user/#{author}">#{author}</a>
            <a href="/r/ruby/comments/#{slug}/story-#{slug}"><h2>#{title}</h2></a>
            <div slot="text-body">Substantive visible body for #{title}.</div>
            #{media}
          </shreddit-post>
        </article>
      HTML
    end.join
    html = <<~HTML
      <html>
        <head>
          <title>reddit for rubyists</title>
          <meta property="og:site_name" content="Reddit">
        </head>
        <body><main><h1>r/ruby</h1><div><shreddit-feed>#{posts}</shreddit-feed></div></main></body>
      </html>
    HTML

    extract_from_url('https://www.reddit.com/r/ruby/', html) do |payload|
      expect(payload).to include(
        'contentType' => 'social',
        'socialKind' => 'feed',
        'platform' => 'Reddit',
        'community' => 'r/ruby',
        'title' => 'reddit for rubyists'
      )

      titles = (1..27).map do |index|
        title = format('Visible subreddit post %02d', index)
        destination = format('https://www.reddit.com/r/ruby/comments/%02d/story-%02d', index, index)
        expect(payload['markdown'].scan(/\[#{Regexp.escape(title)}\]\(/).length).to eq(1)
        expect(payload['markdown'].scan("Substantive visible body for #{title}.").length).to eq(1)
        expect(payload['markdown'].scan(destination).length).to eq(1)
        title
      end
      expect(titles.map { |title| payload['markdown'].index(title) }).to eq(titles.map { |title| payload['markdown'].index(title) }.sort)
      expect(payload['markdown']).to include('https://www.reddit.com/images/final-post.jpg')
    end
  end

  it 'retains ordinary and pinned posts as one complete source-ordered feed' do
    posts = (1..3).map do |index|
      label = format('Community report %02d', index)
      state = index == 3 ? 'pinned highlighted' : 'ordinary card'
      <<~HTML
        <article><shreddit-post class="#{state}" author="writer#{index}" permalink="/r/ruby/comments/#{index}/report-#{index}">
          <a href="/user/writer#{index}">writer#{index}</a>
          <a href="/r/ruby/comments/#{index}/report-#{index}"><h2>#{label}</h2></a>
          <time datetime="2026-09-#{format("%02d", index)}">September #{index}, 2026</time>
          <div slot="text-body">#{label} describes an independent public discussion with complete source details.</div>
        </shreddit-post></article>
      HTML
    end.join
    unrelated = <<~HTML
      <aside><shreddit-post class="pinned highlighted" permalink="/r/ruby/comments/4/unowned-ad">
        <h2>Complementary promotion must not become a feed record</h2>
      </shreddit-post></aside>
    HTML
    html = "<html><head><title>reddit for rubyists</title></head>" \
           "<body><main><h1>r/ruby</h1><shreddit-feed>#{posts}</shreddit-feed>#{unrelated}</main></body></html>"

    extract_from_url('https://www.reddit.com/r/ruby/', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'feed', 'community' => 'r/ruby')
      expect(payload['publishedTime']).to be_nil
      labels = (1..3).map { |index| format('Community report %02d', index) }
      positions = labels.map do |label|
        expect(payload['markdown'].scan(label).length).to be >= 1
        payload['markdown'].index(label)
      end
      expect(positions).to eq(positions.sort)
      labels.each_with_index do |label, index|
        expect(payload['markdown']).to include("#{label} describes an independent public discussion")
        expect(payload['markdown']).to include("https://www.reddit.com/r/ruby/comments/#{index + 1}/report-#{index + 1}")
      end
      expect(payload['markdown']).not_to include('Complementary promotion must not become a feed record')
    end

    extract_from_url('https://www.reddit.com/r/ruby/comments/123/focal-story', html) do |payload|
      expect(payload).not_to include('contentType' => 'social', 'socialKind' => 'feed')
    end
  end

  it 'preserves all Stack Overflow answers in order' do
    answers = repeated_nodes(<<~HTML, 8)
      <div class="answer" data-answerid="%<index>d">
        <div class="js-post-body">Stack Overflow answer %<index>d contains useful detail.</div>
      </div>
    HTML
    html = <<~HTML
      <div id="question"><h1 id="question-header"><a>Ruby blocks</a></h1>
        <div class="js-post-body">How do Ruby blocks work?</div>
      </div>
      <div id="answers" data-answercount="8">#{answers}</div>
    HTML

    extract_from_url('https://stackoverflow.com/questions/123/ruby-blocks', html) do |payload|
      expect(payload).to include('contentType' => 'social', 'socialKind' => 'thread', 'platform' => 'Stack Overflow')
      expect(payload['markdown']).to include('Stack Overflow answer 1', 'Stack Overflow answer 8')
    end
  end
end
