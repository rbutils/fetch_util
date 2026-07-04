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

  it 'prefers structured U.S. Code statutory text over historical notes' do
    html = <<~HTML
      <html>
        <head><title>17 U.S. Code § 107 - Limitations on exclusive rights: Fair use</title></head>
        <body>
          <main>
            <h1 id="page_title">17 U.S. Code § 107 - Limitations on exclusive rights: Fair use</h1>
            <ul class="nav nav-tabs">
              <li><a data-toggle="tab" href="#tab_default_1">Text</a></li>
              <li><a data-toggle="tab" href="#tab_default_2">Notes</a></li>
            </ul>
            <div class="tab-pane active" id="tab_default_1">
              <text>
                <div class="text">
                  <div class="section">
                    <span class="chapeau indent0">Notwithstanding the provisions of sections 106 and 106A, the fair use of a copyrighted work, including such use by reproduction in copies or phonorecords, for purposes such as criticism, comment, news reporting, teaching, scholarship, or research, is not an infringement of copyright. In determining whether the use made of a work in any particular case is a fair use the factors to be considered shall include-</span>
                    <div class="paragraph indent0"><span class="enum">(1)</span> the purpose and character of the use, including whether such use is of a commercial nature or is for nonprofit educational purposes;</div>
                    <div class="paragraph indent0"><span class="enum">(2)</span> the nature of the copyrighted work;</div>
                    <div class="paragraph indent0"><span class="enum">(3)</span> the amount and substantiality of the portion used in relation to the copyrighted work as a whole; and</div>
                    <div class="paragraph indent0"><span class="enum">(4)</span> the effect of the use upon the potential market for or value of the copyrighted work.</div>
                    <div class="continuation indent0">The fact that a work is unpublished shall not itself bar a finding of fair use if such finding is made upon consideration of all the above factors.</div>
                  </div>
                </div>
              </text>
            </div>
            <div class="tab-pane" id="tab_default_2">
              <notes>
                <div class="notes">
                  <p><span>Historical and Revision Notes</span></p>
                  <p><strong>General Background of the Problem.</strong> The judicial doctrine of fair use would be given express statutory recognition for the first time in section 107.</p>
                </div>
              </notes>
            </div>
          </main>
        </body>
      </html>
    HTML

    extract_from_url('https://www.law.cornell.edu/uscode/text/17/107', html) do |payload|
      markdown = payload['markdown']

      expect(payload['contentType']).to eq('article')
      expect(payload['legalProvision']).to be(true)
      expect(payload['warnings']).not_to include('truncated_content')
      expect(markdown).to start_with('# 17 U.S. Code § 107')
      expect(markdown).to include('Notwithstanding the provisions of sections 106 and 106A')
      expect(markdown).to include('the purpose and character of the use')
      expect(markdown).not_to include('Historical and Revision Notes')
      expect(markdown).not_to include('General Background of the Problem')
    end
  end
end
