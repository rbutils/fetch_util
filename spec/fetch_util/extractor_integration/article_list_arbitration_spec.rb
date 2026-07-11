# frozen_string_literal: true

RSpec.describe 'FetchUtil article/list arbitration' do
  include_context 'extractor integration helpers'

  def body_present_fixture
    File.expand_path('../../fixtures/article_route_body_present.html', __dir__)
  end

  def related_only_fixture
    File.expand_path('../../fixtures/article_route_related_only.html', __dir__)
  end

  it 'keeps a DW-style detail with twelve related links as an article' do
    url = 'https://www.dw.com/en/newsroom-report/a-77898335'

    extract_from_url(url, fixture_contents(body_present_fixture)) do |payload|
      expect(payload['contentType']).to eq('article')
      expect(payload['markdown']).to include('The report describes a developing story')
    end
  end

  it 'distinguishes focal BBC articles from related-only article routes' do
    routes = [
      ['https://www.bbc.com/somali/articles/c8r07734dp4o', true],
      ['https://www.bbc.com/somali/articles/c9r07734dp4o', true],
      ['https://www.bbc.com/somali/articles/c0r07734dp4o', false],
      ['https://www.bbc.com/somali/articles/c1r07734dp4o', false],
      ['https://www.bbc.com/yoruba/articles/c8r07734dp4o', true],
      ['https://www.bbc.com/yoruba/articles/c9r07734dp4o', true],
      ['https://www.bbc.com/yoruba/articles/c0r07734dp4o', false],
      ['https://www.bbc.com/yoruba/articles/c1r07734dp4o', false]
    ]

    routes.each do |url, body_present|
      html = fixture_contents(body_present ? body_present_fixture : related_only_fixture)
      extract_from_url(url, html) do |payload|
        expect(payload['contentType']).to eq(body_present ? 'article' : 'list'), url
        if body_present
          expect(payload['markdown']).to include('The report describes a developing story'), url
        else
          expect(payload['markdown']).to include('Related headline'), url
        end
      end
    end
  end

  it 'keeps an article with many inline links from generic list relabeling' do
    url = 'https://news.example/2026/07/11/inline-report'

    extract_from_url(url, fixture_contents(body_present_fixture)) do |payload|
      expect(payload['contentType']).to eq('article')
    end
  end

  it 'keeps a true category index as a list' do
    html = <<~HTML
      <main><h1>Latest reports</h1><section>
        #{(1..8).map { |index| %(<article><h2><a href="/articles/#{index}">Report #{index} headline</a></h2></article>) }.join}
      </section></main>
    HTML

    extract_from_url('https://www.bbc.com/articles', html) do |payload|
      expect(payload['contentType']).to eq('list')
    end
  end

  it 'does not treat an arbitrary non-news a route as an article' do
    html = <<~HTML
      <main><h1>Application dashboard</h1><section>
        #{(1..8).map { |index| %(<article><h2><a href="/items/#{index}">Application item #{index}</a></h2></article>) }.join}
      </section></main>
    HTML

    extract_from_url('https://app.example/a-77898335', html) do |payload|
      expect(payload['contentType']).to eq('list')
    end
  end
end
