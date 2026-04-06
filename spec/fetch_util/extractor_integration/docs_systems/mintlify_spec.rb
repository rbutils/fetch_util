# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts mintlify docs through generic docs-system detection' do
    html = <<~HTML
      <html>
        <head>
          <title>Introduction - Dub</title>
          <meta name="generator" content="Mintlify" />
        </head>
        <body>
          <main>
            <article>
              <nav aria-label="Table of contents">On this page</nav>
              <div>Copy for LLM</div>
              <div>View as Markdown</div>
              <div>API Reference Sidebar</div>
              <h1>Introduction</h1>
              <p>Learn how to use Dub's API to programmatically manage resources.</p>
              <h2>Base URL</h2>
              <p><code>https://api.dub.co</code></p>
            </article>
          </main>
        </body>
      </html>
    HTML

    with_url_page('https://dub.co/docs/api-reference/introduction', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['title']).to eq('Introduction')
      expect(payload['markdown']).to include('# Introduction')
      expect(payload['markdown']).to include('programmatically manage resources')
      expect(payload['markdown']).to include('## Base URL')
      expect(payload['markdown']).not_to include('On this page')
      expect(payload['markdown']).not_to include('Copy for LLM')
      expect(payload['markdown']).not_to include('View as Markdown')
      expect(payload['markdown']).not_to include('API Reference Sidebar')
    end
  end
end
