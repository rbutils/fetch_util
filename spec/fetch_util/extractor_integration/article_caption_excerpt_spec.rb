# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'source-owned article photo-credit excerpts' do
  include_context 'extractor integration helpers'

  def article_with_credit(credit)
    paragraphs = (1..4).map do |index|
      "<p>Reporting paragraph #{index} explains the independent evidence, the public decision, and the affected community with enough detail for a complete account.</p>"
    end.join
    <<~HTML
      <html><head><title>Regional policy briefing</title></head><body>
        <main><article><h1>Regional policy briefing</h1>
          <p>Community event in the capital, 19 January 2026. #{credit}</p>
          #{paragraphs}
        </article></main>
      </body></html>
    HTML
  end

  it 'uses the complete owned report lead when an initial credit line is only a photo caption' do
    with_url_page('https://journal.example.test/articles/regional-policy', article_with_credit('Newsdesk/R Rivera')) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)

      expect(payload['excerpt']).to start_with('Reporting paragraph 1 explains')
      expect(payload['excerpt']).not_to include('Newsdesk/R Rivera')
      expect(payload['markdown']).to include('Newsdesk/R Rivera', 'Reporting paragraph 1', 'Reporting paragraph 4')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'keeps an ordinary dated introduction without a photo credit as the excerpt' do
    html = article_with_credit('The municipal review describes a second phase of policy.')
    with_url_page('https://journal.example.test/articles/municipal-review', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to start_with('Community event in the capital')
      expect(payload['markdown']).to include('Reporting paragraph 4')
    end
  end

  it 'does not promote an unrelated lead when the credited article has no complete body series' do
    html = article_with_credit('Newsdesk/R Rivera').gsub(%r{<p>Reporting paragraph [2-4].*?</p>}, '')
    with_url_page('https://journal.example.test/articles/short-notice', html) do |page|
      payload = extract_payload(page)
      expect(payload['excerpt']).to start_with('Community event in the capital')
      expect(payload['markdown']).to include('Reporting paragraph 1')
    end
  end
end
