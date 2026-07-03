# frozen_string_literal: true

RSpec.describe 'FetchUtil academic abstract extraction' do
  include_context 'extractor integration helpers'

  it 'surfaces arXiv abstract details instead of sidebar tooling' do
    html = <<~HTML
      <html>
        <head>
          <title>[1706.03762] Attention Is All You Need</title>
          <meta property="og:site_name" content="arXiv.org">
        </head>
        <body>
          <main>
            <h1 class="title mathjax">Title: Attention Is All You Need</h1>
            <div class="authors"><span>Authors:</span> Ashish Vaswani, Noam Shazeer</div>
            <div class="dateline">Submitted on 12 Jun 2017</div>
            <blockquote class="abstract mathjax">
              <span class="descriptor">Abstract:</span>
              The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.
            </blockquote>
          </main>
          <aside>
            <h1>Bibliographic and Citation Tools</h1>
            <h1>arXivLabs: experimental projects with community collaborators</h1>
            <p>arXivLabs is a framework that allows collaborators to develop and share new arXiv features.</p>
            <section class="cards">
              <h2><a href="/labs/a">Bibliographic Explorer</a></h2>
              <h2><a href="/labs/b">ScienceCast</a></h2>
              <h2><a href="/labs/c">Influence Flower</a></h2>
              <h2><a href="/labs/d">Smart Citations</a></h2>
              <h2><a href="/labs/e">Hugging Face</a></h2>
              <h2><a href="/labs/f">CatalyzeX Code Finder</a></h2>
            </section>
          </aside>
        </body>
      </html>
    HTML

    extract_from_url('https://arxiv.org/abs/1706.03762', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(markdown).to include('# Attention Is All You Need')
      expect(markdown).to include('Author: Ashish Vaswani, Noam Shazeer')
      expect(markdown).to include('The dominant sequence transduction models')
      expect(markdown).to include('Submitted on 12 Jun 2017')
      expect(markdown).not_to include('Bibliographic and Citation Tools')
      expect(markdown).not_to include('arXivLabs is a framework')
    end
  end
end
