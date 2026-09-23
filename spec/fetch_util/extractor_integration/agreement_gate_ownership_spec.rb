# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'FetchUtil extractor integration - agreement gate ownership' do
  include_context 'extractor integration helpers'

  it 'does not assemble a login gate from public product copy and separate header and footer controls' do
    features = (1..12).map do |index|
      <<~HTML
        <section><h2>Public product capability #{index}</h2>
          <p>Capability #{index} explains how teams manage access across devices and improve security
          without interrupting productive work or hiding the public explanation of the service.</p>
        </section>
      HTML
    end.join
    html = <<~HTML
      <html><head><title>Secure workplace accounts</title></head><body>
        <div class="site-shell">
          <header><button>Login</button></header>
          <main>
            <h1>Keep your team secure</h1>
            <section><h2>Protect employee credentials at every login</h2>
              <p>Help employees use stronger credentials with guidance and oversight.</p></section>
            #{features}
          </main>
          <footer>
            <a href="/tools/username-generator">Username Generator</a>
            <a href="/user-agreement">User Agreement</a>
            <a href="/privacy-policy">Privacy Policy</a>
          </footer>
        </div>
      </body></html>
    HTML

    with_url_page('https://accounts.example.test/', html) do |page|
      payload = FetchUtil::Extractor.new.extract(page)

      expect(payload['markdown']).to include('Public product capability 1')
      expect(payload['warnings']).not_to include('auth_or_login_interstitial')
      expect(payload['warnings']).not_to include('consent_interstitial')
      expect(payload['contentType']).not_to eq('interstitial')
    end
  end
end
