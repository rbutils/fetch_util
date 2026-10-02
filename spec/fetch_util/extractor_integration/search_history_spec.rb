# frozen_string_literal: true

RSpec.describe 'Source-owned search history' do
  include_context 'extractor integration helpers'

  def search_history_page(entries, extra: '')
    rows = entries.map do |entry|
      next entry[:html] if entry[:html]

      label = entry.fetch(:query, entry[:text])
      link = entry[:linked] ? %(<a href="/search/?text=#{CGI.escapeHTML(label)}">#{label}</a>) : label
      detail = entry[:detail] ? %(<time>#{entry[:detail]}</time>) : ''
      "<li>#{link} #{detail}</li>"
    end.join
    <<~HTML
      <html><head><title>Search</title></head><body>
        <main><h1>Search results</h1><form action="/search/" method="get">
          <input type="search" name="text"><button>Search</button>
        </form><h2>Search history</h2><ul>#{rows}</ul>#{extra}</main>
      </body></html>
    HTML
  end

  def evaluate_search_history_candidate(page)
    root = File.expand_path('../../..', __dir__)
    manifest = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
    source = manifest.reject { |path| path.empty? || path.start_with?('#') }.map do |path|
      File.read(File.join(root, 'websieve', path))
    end.join("\n")
    source.sub!('})(window);', 'window.__searchHistoryCandidate = sourceOwnedSearchHistoryContent; })(window);')
    page.add_script_tag(content: source)
    JSON.parse(page.evaluate('JSON.stringify(window.__searchHistoryCandidate({ title: document.title, siteName: location.hostname }))'))
  end

  it 'retains every owned public query term in source order, including short and unlinked terms' do
    entries = [
      { text: 'Alpha', linked: true },
      { text: 'X', linked: true },
      { text: 'Gamma', linked: false },
      { text: 'BETA', linked: true }
    ]
    html = search_history_page(entries)

    with_url_page('https://publisher.example/search/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['excerpt']).to eq('Alpha')
      expect(payload['markdown'].lines.grep(/^- /).length).to eq(4)
      positions = entries.map { |entry| payload['markdown'].index(entry[:text]) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(payload['markdown']).to include('Alpha', 'X', 'Gamma', 'BETA')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'retains repeated query events independently with their visible time and detail' do
    entries = [
      { text: 'Atlas 08:10 first event', query: 'Atlas', linked: true, detail: '08:10 first event' },
      { text: 'Atlas 08:45 second event', query: 'Atlas', linked: true, detail: '08:45 second event' },
      { text: 'Beacon', linked: true }
    ]

    with_url_page('https://publisher.example/search/', search_history_page(entries)) do |page|
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('list')
      expect(payload['markdown'].lines.grep(/^- /).length).to eq(3)
      expect(payload['markdown']).to include('Atlas 08:10 first event', 'Atlas 08:45 second event')
      expect(payload['markdown'].index('08:10')).to be < payload['markdown'].index('08:45')
    end
  end

  it 'declines the entire history takeover when any row has multiple links or linked media' do
    invalid_rows = [
      %(<li><a href="/search/?text=Delta">Delta</a><a href="/details/">Details</a></li>),
      %(<li><a href="/search/?text=Delta">Delta</a><img src="/media/cover.png" alt="Cover"></li>)
    ]
    invalid_rows.each do |invalid_row|
      entries = [
        { text: 'Alpha', linked: true },
        { html: invalid_row },
        { text: 'Beacon', linked: true }
      ]

      with_url_page('https://publisher.example/search/', search_history_page(entries)) do |page|
        expect(evaluate_search_history_candidate(page)).to be_nil
      end
    end
  end

  it 'declines a mixed genuine and foreign collection instead of returning a partial list' do
    entries = [
      { text: 'Alpha', linked: true },
      { html: %(<li><a href="https://other.example/search/?text=Delta">Delta</a></li>) },
      { text: 'Beacon', linked: true }
    ]

    with_url_page('https://publisher.example/search/', search_history_page(entries)) do |page|
      expect(evaluate_search_history_candidate(page)).to be_nil
    end
  end

  it 'keeps a focal article with a history-shaped example as an article' do
    entries = [{ text: 'Alpha', linked: true }, { text: 'Beacon', linked: true }]
    prose = 'This independently owned article explains the example search interface and its history records in substantial detail for readers. ' * 12
    html = search_history_page(entries).sub(
      '</main>',
      "<p>#{prose}</p></main>"
    )

    with_url_page('https://publisher.example/search/', html) do |page|
      expect(evaluate_search_history_candidate(page)).to be_nil
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('independently owned article explains the example search interface')
    end
  end

  it 'does not promote unrelated, quoted, hidden, or unassociated lists' do
    entries = [{ text: 'First query', linked: true }, { text: 'Second query', linked: true }]
    html = <<~HTML
      <html><head><title>Article with a search control</title></head><body>
        <main><h1>Article with a search control</h1>
          <form><input type="search" name="text"></form>
          <aside><h2>Search history</h2><ul>#{entries.map { |entry| "<li><a href='/search/?text=#{entry[:text].tr(" ", "+")}'>#{entry[:text]}</a></li>" }.join}</ul></aside>
          <blockquote><h2>Search history</h2><ul><li><a href="/search/?text=quoted">quoted</a></li></ul></blockquote>
          <div hidden><h2>Search history</h2><ul><li><a href="/search/?text=hidden">hidden</a></li></ul></div>
          <p>This article remains the independently selected public text and is not a search-history result list.</p>
          <p>Its ordinary prose has an owner, while the nearby lists are not the primary history records.</p>
        </main>
      </body></html>
    HTML

    with_url_page('https://publisher.example/search/', html) do |page|
      expect(evaluate_search_history_candidate(page)).to be_nil
      payload = FetchUtil::Extractor.new(reader_mode: false).extract(page)

      expect(payload['markdown']).to include('Article with a search control')
    end
  end

  it 'rejects an empty sign-in shell and a real verification challenge' do
    empty_shell = <<~HTML
      <html><head><title>Sign in</title></head><body><main>
        <h1>Sign in</h1><form><input type="search" name="text"></form>
        <h2>Search history</h2><ul><li>Sign in to see your history</li></ul>
      </main></body></html>
    HTML
    challenge = search_history_page([{ text: 'First', linked: true }, { text: 'Second', linked: true }])
    challenge = challenge.sub('<title>Search</title>', '<title>Just a moment...</title>')
    challenge = challenge.sub(
      '</main>',
      '<p>Performing security verification. This website uses a security service to protect against malicious bots.</p></main>'
    )

    with_url_page('https://publisher.example/search/', empty_shell) do |page|
      expect(evaluate_search_history_candidate(page)).to be_nil
    end
    with_url_page('https://publisher.example/search/', challenge) do |page|
      expect(evaluate_search_history_candidate(page)).to be_nil
    end
  end
end
