RSpec.describe 'Generic ownership of bounded Contents components' do
  include_context 'extractor integration helpers'

  let(:guidance_html) do
    fixture_contents(File.expand_path('../../fixtures/govuk_guidance.html', __dir__))
  end
  let(:guidance_url) { 'https://example.test/guidance/rates-and-thresholds-for-employers-2026-to-2027' }
  let(:lead) { 'Use these synthetic rates and thresholds when you configure the example payroll record.' }

  it 'binds the unchanged original guidance header, metadata, Contents links and body' do
    extract_from_url(guidance_url, guidance_html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['title']).to eq('Rates and thresholds for employers 2026 to 2027')
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
      expect(payload['excerpt']).to eq(lead)
      expect(payload['contentFormat']).not_to eq('liveblog')
      expect(payload['markdown']).to include("# Rates and thresholds for employers 2026 to 2027\n\n#{lead}")
      expect(payload['markdown']).to match(/\[PAYE tax and Class 1 National Insurance contributions\]\([^)]*#paye-tax-and-class-1-national-insurance-contributions\)/)
      expect(payload['markdown']).to match(/\[Tax thresholds, rates and codes\]\([^)]*#tax-thresholds-rates-and-codes\)/)
      expect(payload['markdown']).to match(/\[National Minimum Wage\]\([^)]*#national-minimum-wage\)/)
      expect(payload['html']).to include('HM Revenue &amp; Customs')
      expect(payload['html']).to include('id="england-and-northern-ireland"')
      expect(payload['markdown']).to include('242 sample units per week', '1,048 sample units per month', '12,570 sample units per year')
      expect_warnings(payload, exclude: %w[empty_extraction not_found_interstitial url_content_mismatch])
    end
  end

  it 'matches visible Contents labels when source markup spaces parentheses differently' do
    html = guidance_html.sub(
      '>Tax thresholds, rates and codes</a>',
      '>Tax thresholds, rates and codes (PSAs)</a>'
    ).sub(
      '<h2 id="tax-thresholds-rates-and-codes">Tax thresholds, rates and codes</h2>',
      '<h2 id="tax-thresholds-rates-and-codes">Tax thresholds, rates and codes ( PSAs )</h2>'
    )

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['markdown']).to match(/\[Tax thresholds, rates and codes \(PSAs\)\]\([^)]*#tax-thresholds-rates-and-codes\)/)
    end
  end

  it 'retains bounded update history in source order when source timestamps omit minute padding' do
    canonical = "<link rel=\"canonical\" href=\"#{guidance_url}\">"
    schema = {
      '@context' => 'https://schema.org',
      '@type' => 'FAQPage',
      'mainEntityOfPage' => { '@type' => 'WebPage', '@id' => guidance_url },
      'name' => 'Rates and thresholds for employers 2026 to 2027',
      'text' => lead,
      'author' => { '@type' => 'Organization', 'name' => 'HM Revenue & Customs' },
      'datePublished' => '2026-01-30T10:09:00+00:00',
      'dateModified' => '2026-09-01T00:15:03Z'
    }
    history = <<~HTML
      <section class="gem-c-published-dates">
        <h2>Updates to this page</h2>
        <ol>
          <li><time datetime="2026-01-30T10:9:00Z">30 January 2026</time><p>Initial guidance was published.<span hidden>Hidden revision detail.</span></p></li>
          <li><time datetime="2026-09-01T00:15:03Z">1 September 2026</time><p>The sample payroll rates were updated.</p></li>
        </ol>
      </section>
    HTML
    closing = "        </div>\n      </div>\n    </main>"
    html = guidance_html.sub('</head>', "#{canonical}<script type=\"application/ld+json\">#{JSON.generate(schema)}</script></head>")
    html = html.sub(closing, "        </div>\n        #{history}\n      </div>\n    </main>")
    expect(html).not_to eq(guidance_html)

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
      expect(payload['contentFormat']).not_to eq('liveblog')
      expect(payload['html'].scan('Updates to this page').length).to eq(1)
      expect(payload['html']).to include('datetime="2026-01-30T10:9:00Z"', 'datetime="2026-09-01T00:15:03Z"')
      expect(payload['markdown']).to include('Initial guidance was published.', 'The sample payroll rates were updated.')
      expect(payload['html']).not_to include('Hidden revision detail.')
      expect(payload['markdown']).not_to include('Hidden revision detail.')
      initial_update_position = payload['markdown'].index('Initial guidance was published.')
      latest_update_position = payload['markdown'].index('The sample payroll rates were updated.')
      expect(initial_update_position).to be < latest_update_position
    end
  end

  it 'preserves source-controlled collapsed update history in source order' do
    canonical = "<link rel=\"canonical\" href=\"#{guidance_url}\">"
    schema = {
      '@context' => 'https://schema.org',
      '@type' => 'FAQPage',
      'mainEntityOfPage' => { '@type' => 'WebPage', '@id' => guidance_url },
      'name' => 'Rates and thresholds for employers 2026 to 2027',
      'text' => lead,
      'author' => { '@type' => 'Organization', 'name' => 'HM Revenue & Customs' },
      'datePublished' => '2026-01-30T10:09:00+00:00',
      'dateModified' => '2026-09-01T00:15:03Z'
    }
    history = <<~HTML
      <section class="gem-c-published-dates">
        <h2 class="govuk-visually-hidden">Updates to this page</h2>
        <div>Published 30 January 2026</div>
        Last updated 1 September 2026
        <a href="#full-history" data-controls="full-history" aria-controls="full-history" aria-expanded="false">Show all updates</a>
        <div id="full-history" style="display: none !important; visibility: hidden !important">
          <ol>
            <li style="visibility: hidden !important"><time datetime="2026-01-30T10:9:00Z">30 January 2026</time><p>Hidden initial change.</p></li>
            <li style="visibility: hidden !important"><time datetime="2026-09-01T00:15:03Z">1 September 2026</time><p>Hidden later change.</p></li>
          </ol>
        </div>
      </section>
    HTML
    closing = "        </div>\n      </div>\n    </main>"
    html = guidance_html.sub('</head>', "#{canonical}<script type=\"application/ld+json\">#{JSON.generate(schema)}</script></head>")
    html = html.sub(closing, "        </div>\n        #{history}\n      </div>\n    </main>")

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
      expect(payload['html']).to include('Last updated 1 September 2026', 'Show all updates')
      expect(payload['html']).to include('Hidden initial change.', 'Hidden later change.')
      expect(payload['markdown']).to include('Last updated 1 September 2026', 'Show all updates')
      expect(payload['markdown']).to include('Hidden initial change.', 'Hidden later change.')
      expect(payload['markdown'].index('Hidden initial change.')).to be < payload['markdown'].index('Hidden later change.')
    end

    unowned_history = html.sub('aria-controls="full-history"', 'aria-controls="other-history"')
    extract_from_url(guidance_url, unowned_history) do |payload|
      expect(payload['markdown']).not_to include('Hidden initial change.', 'Hidden later change.')
    end
  end

  it 'ignores a foreign same-main sidebar definition list without replacing the owned metadata' do
    foreign = '<aside><dl><dt>From:</dt><dd>Unrelated Office</dd>' \
      '<dt>Published:</dt><dd>1 January 1999</dd></dl></aside>'
    html = guidance_html.sub('</main>', "#{foreign}</main>")

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['publishedTime']).to eq('2026-01-30T10:09:00+00:00')
      expect(payload['html']).not_to include('Unrelated Office')
      expect(payload['markdown']).to match(/\[PAYE tax and Class 1 National Insurance contributions\]\([^)]*#paye-tax-and-class-1-national-insurance-contributions\)/)
    end
  end

  it 'prunes hidden descendants from the owned metadata values' do
    html = guidance_html.sub(
      '<dd class="gem-c-metadata__definition"><a href="/government/organisations/hm-revenue-customs">',
      '<dd class="gem-c-metadata__definition"><span hidden>Unrelated Office</span><a href="/government/organisations/hm-revenue-customs">'
    )

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['byline']).to eq('HM Revenue & Customs')
      expect(payload['markdown']).not_to include('Unrelated Office')
    end
  end

  it 'defers to ordinary extraction when a bounded component contains competing navigation branches' do
    foreign_nav = '<nav aria-label="Contents"><h2>Contents</h2><ol><li><a href="#foreign-section">Foreign section</a></li></ol></nav>'
    html = guidance_html.sub('</nav>', "</nav>#{foreign_nav}")

    expect_unproved_contents_to_use_ordinary_extraction(html)
  end

  it 'defers to ordinary extraction when a Contents target belongs to a sibling section' do
    foreign_link = '<li><a href="#foreign-section">Foreign section</a></li>'
    html = guidance_html.sub('</ol>', "#{foreign_link}</ol>").sub(
      '</main>', '<section><h2 id="foreign-section">Foreign section</h2><p>Separate visible material.</p></section></main>'
    )

    expect_unproved_contents_to_use_ordinary_extraction(html)
  end

  it 'uses ordinary comment ownership rather than omitting a same-main discussion thread' do
    comments = '<section id="comments" class="comments"><h2>Comments</h2>' \
      '<article class="comment"><p>A visible reader comment belongs to this page.</p></article></section>'
    html = guidance_html.sub('</main>', "#{comments}</main>")

    extract_from_url(guidance_url, html) do |payload|
      expect(payload['markdown']).to include('A visible reader comment belongs to this page.')
    end
  end

  it 'keeps a declared article byline and date despite a foreign same-main Contents component' do
    html = ordinary_article_with_foreign_contents(author: 'A. Writer')

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['byline']).to eq('A. Writer')
      expect(payload['publishedTime']).to eq('2025-12-17T09:30:00Z')
      expect(payload['markdown']).not_to include('[Foreign heading]')
    end
  end

  it 'does not invent a byline or replace the date from a foreign same-main Contents component' do
    html = ordinary_article_with_foreign_contents(author: nil)

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['byline']).to be_nil
      expect(payload['publishedTime']).to eq('2025-12-17T09:30:00Z')
      expect(payload['markdown']).not_to include('[Foreign heading]')
    end
  end

  it 'does not replace an independently selected Reader article because of a foreign Contents component' do
    html = ordinary_article_with_foreign_contents(author: 'A. Writer').sub(
      'A first visible paragraph in an ordinary unknown-host article.',
      'The field report describes an independently owned article, with detailed observations and supporting evidence. ' * 8
    ).sub(
      'A second visible paragraph preserves the complete article body.',
      'The later account explains the results, preserves the important context, and discusses what the researchers observed. ' * 8
    )
    without_component = html.sub(%r{<div data-module="contents-list-with-body">.*?</div></main>}m, '</main>')
    reference = nil
    extract_from_url('https://example.test/ordinary-story', without_component) { |payload| reference = payload }
    expect(reference['readerMode']).to be(true)

    extract_from_url('https://example.test/ordinary-story', html) do |payload|
      expect(payload['readerMode']).to eq(reference['readerMode'])
      expect(payload['markdown']).to eq(reference['markdown'])
      expect(payload['byline']).to eq(reference['byline'])
      expect(payload['publishedTime']).to eq(reference['publishedTime'])
    end
  end

  def expect_unproved_contents_to_use_ordinary_extraction(html)
    ordinary_html = html.sub('data-module="contents-list-with-body"', '')
    expect(ordinary_html).not_to eq(html)
    reference = nil
    extract_from_url(guidance_url, ordinary_html) { |payload| reference = payload }

    extract_from_url(guidance_url, html) do |payload|
      fields = %w[title byline publishedTime excerpt markdown readerMode contentType warnings]
      expect(payload.values_at(*fields)).to eq(reference.values_at(*fields))
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('The example payroll uses PAYE so HMRC can record the synthetic deductions.')
    end
  end

  def ordinary_article_with_foreign_contents(author:)
    author_data = author ? %("author":{"@type":"Person","name":"#{author}"},) : ''
    <<~HTML
      <!doctype html><html><head>
      <title>Ordinary article</title>
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"Ordinary article",#{author_data}"datePublished":"2025-12-17T09:30:00Z"}</script>
      </head><body><main><article><h1>Ordinary article</h1>
      <p>A first visible paragraph in an ordinary unknown-host article.</p>
      <p>A second visible paragraph preserves the complete article body.</p>
      <dl><dt>Agency</dt><dd>Foreign Agency</dd><dt>Published</dt><dd>1999-01-01</dd></dl>
      </article>
      <div data-module="contents-list-with-body">
        <div><nav><h2>Contents</h2><ol><li><a href="#foreign-heading">Foreign heading</a></li></ol></nav></div>
        <div><h2 id="foreign-heading">Foreign heading</h2><p>This section is unrelated to the article.</p></div>
      </div></main></body></html>
    HTML
  end
end
