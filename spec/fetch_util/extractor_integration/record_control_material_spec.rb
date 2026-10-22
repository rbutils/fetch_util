# frozen_string_literal: true

RSpec.describe 'source-ordered record control material' do
  include_context 'extractor integration helpers'

  it 'preserves counts, prose, programs and resources while cleaning control-only metadata' do
    program = "Last Post: 2h ago\n42 replies - Last post 5h ago"
    records = (1..5).map do |index|
      extra = if index == 1
                <<~HTML
                  <pre><code><span>Last Post: 2h ago</span>\n42 replies - Last post 5h ago</code></pre>
                  <span><img src="/record.png" alt="Last Post"></span>
                  <span><strong>Last Post</strong> is an authored label.</span>
                HTML
              end
      <<~HTML
        <div class="topic-list-item">
          <h3><a href="/reports/#{index}">Independent publication report #{index}</a></h3>
          <span>#{index * 10} replies - Last post 2h ago</span>
          <span><span>Last Post</span><span>7h ago</span><span>by editor</span></span>
          <p>Last post at the conference covered publication #{index}.</p>
          <p><span>Last Post: 7h ago</span> is quoted in this authored paragraph.</p>
          #{extra}
        </div>
      HTML
    end.join
    html = "<main><h1>Publication reports</h1><div class=\"topic-list\">#{records}</div></main>"

    with_url_page('https://publication.example.test/', html) do |page|
      before = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      markdown = payload.fetch('markdown')
      programs = markdown.scan(/```[^\n]*\n(.*?)```/m).flatten
      native = Nokogiri::HTML5.fragment(payload.fetch('html'))

      expect(payload['contentType']).to eq('list')
      expect(programs).to eq(["#{program}\n"])
      (1..5).each do |index|
        expect(markdown).to include("#{index * 10} replies")
        expect(markdown).to include("Last post at the conference covered publication #{index}.")
      end
      quotation = 'Last Post: 7h ago is quoted in this authored paragraph.'
      expect(native.css('p').count { |node| node.text == quotation }).to eq(5)
      expect(markdown).to include(quotation)
      expect(markdown).to include('**Last Post** is an authored label.')
      expect(markdown).to include('https://publication.example.test/record.png')
      expect(markdown).not_to include('by editor')
      expect(markdown.gsub(/```[^\n]*\n.*?```/m, '')).not_to include('replies - Last post')
      expect(native.css('h3 a').map { |node| node['href'] }).to eq((1..5).map { |index| "https://publication.example.test/reports/#{index}" })
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
    end
  end
end
