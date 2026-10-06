# frozen_string_literal: true

RSpec.describe 'FetchUtil Joomla extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts Joomla article bodies through shared focal ownership without outside module chrome' do
    expect_fixture_article(
      url: 'https://www.joomla.org/announcements/release-news/5955-joomla-6-1-2-5-4-7-security-bugfix-release.html',
      fixture_path: File.expand_path('../fixtures/joomla_article.html', __dir__),
      includes: [
        'Joomla! Project is pleased announce release Joomla 6.1.2',
        'security & bugfix releases'
      ],
      excludes: ['Breadcrumb', 'Pagination', 'Module chrome', 'Sidebar module'],
      warning_excludes: %w[empty_extraction short_extraction url_content_mismatch consent_interstitial]
    )
  end

  it 'retains authored module-like content and open accordion prose on an unknown host' do
    body = (1..4).map do |number|
      %(<p>Release paragraph #{number} explains the migration, supported deployment choices, and compatibility guarantees for readers.</p>)
    end.join
    html = <<~HTML
      <html><head><title>Deployment release guide | Example publisher</title></head><body>
        <div class="module">Outside subscription module</div>
        <article><h1>Deployment release guide</h1><div class="article-content">
          #{body}
          <section class="module"><h2>Authored migration supplement</h2>
            <p>The authored supplement documents the configuration changes and contains substantive release instructions for every installation.</p>
            <a href="/migration">Complete migration reference</a>
          </section>
          <details open><summary>Deployment choices</summary>
            <p>Visible accordion guidance explains the available deployment modes and the rollback procedure.</p>
            <pre><code>deploy --verify\nrollback --previous</code></pre>
          </details>
        </div></article>
        <nav>Outside pagination links</nav>
      </body></html>
    HTML

    with_url_page('https://ownership.example/releases/deployment-guide', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)
      markdown = payload.fetch('markdown')

      expect(payload.fetch('title')).to eq('Deployment release guide | Example publisher')
      offsets = (1..4).map { |number| markdown.index("Release paragraph #{number}") }
      expect(offsets).to all(be_a(Integer))
      expect(offsets).to eq(offsets.sort)
      expect(markdown).to include('Authored migration supplement', 'Visible accordion guidance')
      expect(markdown).to include('[Complete migration reference](https://ownership.example/migration)')
      expect(markdown).to include("deploy --verify\nrollback --previous")
      expect(markdown).not_to include('Outside subscription module', 'Outside pagination links')
    end
  end
end
