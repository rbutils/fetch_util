# frozen_string_literal: true

RSpec.describe 'FetchUtil legal statute extraction' do
  include_context 'extractor integration helpers'

  it 'extracts official statute full-text bodies instead of table-of-contents links' do
    full_url = 'https://www.gesetze.example/englisch_code/englisch_code.html'
    full_html = <<~HTML
      <html>
        <head><title>Example Criminal Code</title></head>
        <body>
          <div id="container">
            <h1>Example Criminal Code</h1>
            <div id="paddingLR12">
              <p>Translation provided by the official translation service.</p>
              <p>Version information: The translation includes amendments published in the Federal Law Gazette.</p>
              <p>Full citation: Criminal Code in the version published in the Federal Law Gazette.</p>
              <p><a name="p0016"></a>Section 1<br>No punishment without law</p>
              <p>An act can only incur penalty if criminal liability was established by law before the act was committed.</p>
              <p><a name="p0018"></a>Section 2<br>Temporal application</p>
              <p>(1) The penalty and any incidental legal consequences are determined by the law in force at the time of the act.</p>
              <p>(2) If the threatened penalty is amended during commission of the act, the law in force when the act was completed is to be applied.</p>
              <p><a name="p0025"></a>Section 3<br>Application on territory</p>
              <p>German criminal law applies to offences committed on German territory.</p>
            </div>
          </div>
        </body>
      </html>
    HTML

    extract_from_url(full_url, full_html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(markdown).to include('# Example Criminal Code')
      expect(markdown).to include('Section 1  
No punishment without law')
      expect(markdown).to include('An act can only incur penalty')
      expect(markdown).to include('Section 2  
Temporal application')
      expect(markdown).to include('German criminal law applies to offences committed on German territory')
      expect(markdown).not_to include('| General Part |')
      expect(markdown).not_to include('table of contents')
    end
  end
end
