# frozen_string_literal: true

require 'cgi'
require 'digest'

RSpec.describe 'Canonical article header ownership' do
  include_context 'extractor integration helpers'

  def extract_header_case(name)
    html = fixture_contents("spec/fixtures/article_header_ownership/#{name}.html")
    url = {
      'lead-only' => 'https://headers.example/articles/harbor-reopening',
      'hero-only' => 'https://headers.example/articles/reservoir-repair',
      'short-lead' => 'https://headers.example/articles/bridge-inspection',
      'nested-header' => 'https://headers.example/articles/coastal-repair',
      'foreign-header' => 'https://headers.example/articles/harbor-safety',
      'ambiguous-headline' => 'https://headers.example/articles/ambiguous-harbor'
    }.fetch(name)

    with_url_page(url, html) { |page| extract_payload(page) }
  end

  it 'retains an owned lead without requiring hero media' do
    payload = extract_header_case('lead-only')

    expect(payload['contentType']).to eq('article')
    expect(payload['title']).to eq('Harbor reopening update')
    expect(payload['markdown']).to include(
      'Municipal crews finished the eastern pier inspection before the morning ferry service',
      'Engineers confirmed that the harbor route can reopen',
      'Ferry operators will publish the complete revised schedule'
    )
  end

  it 'retains an owned hero figure without requiring a lead' do
    payload = extract_header_case('hero-only')

    expect(payload['contentType']).to eq('article')
    expect(payload['title']).to eq('Reservoir repair notice')
    expect(payload['markdown']).to include(
      'Crews repairing the reservoir intake',
      'Workers secure the intake before the next inspection',
      'Water engineers began the planned reservoir repairs'
    )
  end

  it 'retains a short owned lead and hero without a text-length threshold' do
    payload = extract_header_case('short-lead')

    expect(payload['contentType']).to eq('article')
    expect(payload['markdown']).to include(
      'Brief update',
      'Inspectors checking the bridge deck',
      'Inspectors examine the bridge deck during the scheduled check',
      'Engineers completed the full bridge inspection'
    )
  end

  it 'preserves the complete unique outer header around nested headline markup' do
    payload = extract_header_case('nested-header')

    expect(payload['contentType']).to eq('article')
    expect(payload['markdown']).to include(
      'Crews completed the first seawall survey',
      'Survey crew measuring the inner seawall',
      'The survey team records the condition of the inner wall',
      'The outer section remains under review',
      'Outer seawall beside the open harbor route',
      'Crews monitor the outer wall from the open harbor route',
      'Engineers will publish the complete repair plan'
    )
  end

  it 'retains a bounded structural header without a header element or class' do
    url = 'https://headers.example/news/1618345'
    html = <<~HTML
      <html><head>
        <title>Bridge inspection update</title>
        <link rel="canonical" href="#{url}">
        <meta property="og:type" content="article">
        <meta property="og:title" content="Bridge inspection update">
        <meta property="article:published_time" content="2026-09-23T08:00:00Z">
        <meta name="author" content="Harbor Desk">
      </head><body>
        <section class="detail-right">
          <div class="detail-right-top">
            <h1>Bridge inspection update</h1>
            <p class="lead">Brief update</p>
            <figure><img src="/bridge.jpg" alt="Inspectors checking the bridge deck">
              <figcaption>Inspectors examine the bridge deck during the scheduled check.</figcaption>
            </figure>
            <ul class="article-resources">
              <li><a href="mailto:reporter@example.org">Email</a></li>
              <li><a href="https://jang.com.pk/reports/harbor-support-review.pdf">Print</a></li>
              <li><a class="social_icon" href="https://jang.com.pk/profiles/harbor-author">Reporter profile</a></li>
            </ul>
            <div class="full_social social_mobile"><ul><li class="full_fb">
              <a data-event_label="facebook" rel="nofollow" title="Share on facebook" href="https://www.facebook.com/sharer.php?u=#{CGI.escape("https://jang.com.pk/news/1618962")}">
                <span class="full_social_icon"><img src="/social.svg" alt="Facebook"></span>
              </a>
            </li></ul></div>
          </div>
          <div class="detail-content"><div class="description-area"><div class="detail_view_content">
            <p>Engineers completed the full bridge inspection and confirmed the northbound route can reopen after crews replace the damaged support and publish the revised transit schedule.</p>
          </div></div></div>
        </section>
      </body></html>
    HTML

    with_url_page(url, html) do |page|
      payload = extract_payload(page)

      expect(payload['contentType']).to eq('article')
      expect(payload['title']).to eq('Bridge inspection update')
      expect(payload['publishedTime']).to eq('2026-09-23T08:00:00Z')
      expect(payload['byline']).to eq('Harbor Desk')
      expect(payload['html']).to include('/bridge.jpg', 'Inspectors examine the bridge deck during the scheduled check')
      expect(payload['html']).to include(
        'mailto:reporter@example.org', 'https://jang.com.pk/reports/harbor-support-review.pdf',
        'https://jang.com.pk/profiles/harbor-author'
      )
      expect(payload['html']).not_to include('/social.svg', 'facebook.com/sharer.php')
      expect(payload['markdown']).to include(
        'Brief update', 'Inspectors examine the bridge deck during the scheduled check',
        'Engineers completed the full bridge inspection'
      )
    end
  end

  it 'declines takeover when a foreign article interrupts the header context' do
    payload = extract_header_case('foreign-header')

    expect(payload['contentType']).to eq('article')
    expect(payload['title']).to eq('Harbor safety bulletin')
    expect(payload['markdown']).to include('A separate flood response story', 'The safety crew inspects the pier')
    expect(Digest::SHA256.hexdigest(payload.fetch('markdown'))).to eq(
      '059d3ae13defc47e4f793606a102fc200f45dbe11d94adcf3e192ddb523447f9'
    )
  end

  it 'declines takeover when matching page headlines are ambiguous' do
    payload = extract_header_case('ambiguous-headline')

    expect(payload['contentType']).to eq('article')
    expect(payload['title']).to eq('Ambiguous harbor update')
    expect(payload['markdown']).to include('Two teams review the same harbor plan', 'Residents can read the complete inspection notes')
    expect(Digest::SHA256.hexdigest(payload.fetch('markdown'))).to eq(
      '88a6c6191d80f62150ec2e9a60465776c1c22f59cca3b317a57d5f1cf561c4bc'
    )
  end
end
