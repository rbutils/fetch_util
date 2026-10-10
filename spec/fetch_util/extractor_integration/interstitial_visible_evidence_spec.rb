require 'spec_helper'

RSpec.describe 'Rendered evidence for access interstitial classification' do
  include_context 'extractor integration helpers'

  def public_report_html(runtime_payload)
    paragraphs = (1..8).map do |index|
      "<p>Reporting paragraph #{index} presents a substantive public observation, its supporting context and the published conclusions.</p>"
    end.join
    <<~HTML
      <html><head><title>Public observations</title></head><body>
      <main><article><h1>Public observations</h1>#{paragraphs}</article></main>
      #{runtime_payload}</body></html>
    HTML
  end

  it 'does not turn script literals into a subscription gate over a populated article' do
    html = public_report_html('<script>window.hiddenNotice = "subscriber-only; subscription required; subscribe to continue";</script>')
    with_url_page('https://publication.example.test/report', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('warnings')).not_to include('subscription_interstitial')
      expect(payload.fetch('markdown')).to include('Reporting paragraph 1', 'Reporting paragraph 8')
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end

  it 'does not use inert styles, templates or noscript data as visible access notices' do
    runtime = '<style>:root { --notice: "subscription required"; }</style>' \
              '<template><h1>Subscribe to continue</h1></template><noscript>Institutional access required</noscript>'
    with_url_page('https://publication.example.test/report', public_report_html(runtime)) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('article')
      expect(payload.fetch('warnings')).not_to include('subscription_interstitial')
      expect(payload.fetch('markdown')).to include('Reporting paragraph 8')
    end
  end

  it 'retains a real materialized subscription interstitial' do
    html = '<html><head><title>Subscription required</title></head><body><main>' \
           '<h1>Subscribe to continue</h1><p>Sign in to continue reading this publication.</p>' \
           '<button>Sign in</button><a href="/subscribe">Subscribe</a></main></body></html>'
    with_url_page('https://publication.example.test/report', html) do |page|
      payload = extract(page)
      expect(payload.fetch('contentType')).to eq('interstitial')
      expect(payload.fetch('warnings')).to include('subscription_interstitial')
    end
  end
end
