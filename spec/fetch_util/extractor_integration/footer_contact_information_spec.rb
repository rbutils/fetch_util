# frozen_string_literal: true

RSpec.describe 'Complete source-owned footer contact information' do
  include_context 'extractor integration helpers'

  def contact_information
    <<~HTML
      <div class="footer-information">
        <div><div><span><h2>Publication office</h2></span></div><span>Open Research Foundation</span></div>
        <div>
          <div><div>Address</div><span>42 Science Road<br>Studio 7, Research City</span></div>
          <div><div>Email</div><a href="mailto:office@publication.example.test"><span>office@publication.example.test</span></a></div>
          <div><div>Telephone</div><a href="tel:(+1)%20202%20555%200145"><span>(+1) 202 555 0145</span></a></div>
        </div>
      </div>
    HTML
  end

  def contact_collection_page(footer)
    records = [1, 2, 3, 4, 1].map do |number|
      <<~HTML
        <div class="story-card">
          <a href="/reports/#{number}"><img src="/covers/#{number}.png" alt="Cover #{number}"></a>
          <h2><a href="/reports/#{number}">Field report #{number}</a></h2>
          <p>Published June #{number}, 2026</p>
        </div>
      HTML
    end.join
    <<~HTML
      <html><head><title>Publication archive</title></head><body><form id="page-shell"><div class="page">
        <div id="publication-section"><div><h2>Recent field reports</h2></div>
          <div><span id="records">#{records}</span></div>
        </div>
        #{footer}
      </div></form></body></html>
    HTML
  end

  ['footer', 'div class="site-footer"'].each do |opening|
    it "retains the complete visible contact group inside #{opening} after every independent record" do
      ending = opening.split.first
      hidden = contact_information.sub('footer-information', 'footer-information" style="display:none').gsub('Open Research Foundation', 'Hidden Mobile Foundation')
      footer = <<~HTML
        <#{opening}>
          #{hidden}
          #{contact_information}
          <nav><a href="/account">Account navigation</a><a href="/settings">Account settings</a></nav>
          <div class="newsletter"><h2>Subscribe to publication updates</h2><p>Receive the next issue.</p>
            <input type="email"><button>Subscribe</button>
          </div>
        </#{ending}>
      HTML
      with_url_page('https://publication.example.test/archive/', contact_collection_page(footer)) do |page|
        body = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        output = Nokogiri::HTML5.fragment(payload.fetch('html'))
        expected = ['Recent field reports', *[1, 2, 3, 4, 1].map { |number| "Field report #{number}" }, 'Publication office']
        expect(output.css('h2').map(&:text)).to eq(expected)
        expect(output.css('.story-card').length).to eq(5)
        expect(output.css('p').map(&:text)).to eq([1, 2, 3, 4, 1].map { |number| "Published June #{number}, 2026" })
        contacts = output.css('a').select { |link| link['href'].to_s.match?(/\A(?:mailto|tel):/) }
        expected_contacts = [
          ['office@publication.example.test', 'mailto:office@publication.example.test'],
          ['(+1) 202 555 0145', 'tel:(+1)%20202%20555%200145']
        ]
        expect(contacts.map { |link| [link.text, link['href']] }).to eq(expected_contacts)
        markdown = payload.fetch('markdown')
        values = [
          '## Publication office', 'Open Research Foundation', 'Address', '42 Science Road',
          'Studio 7, Research City', 'Email', 'office@publication.example.test', 'Telephone', '(+1) 202 555 0145'
        ]
        positions = values.map { |value| markdown.index(value) }
        expect(positions).not_to include(nil)
        expect(positions).to eq(positions.sort)
        expect(positions.first).to be > markdown.rindex('Published June 1, 2026')
        expect(markdown.scan('](mailto:office@publication.example.test)').length).to eq(1)
        expect(markdown).to include('](tel:(+1)%20202%20555%200145)')
        expect(markdown).not_to include('Hidden Mobile Foundation', 'Account navigation', 'Subscribe to publication updates', 'Receive the next issue.')
        expect(page.evaluate('document.body.innerHTML')).to eq(body)
      end
    end
  end

  it 'keeps explicitly hidden, closed and control-owned contact groups outside the selected publication body' do
    variants = [
      '<div hidden>GROUP</div>',
      '<details><summary>Contact preferences</summary>GROUP</details>',
      '<nav>GROUP</nav>',
      '<div role="dialog">GROUP</div>',
      'GROUP',
      '<div role="toolbar">GROUP</div>',
      '<div role="alertdialog">GROUP</div>',
      '<div role="complementary">GROUP</div>',
      '<div role="menu">GROUP</div>'
    ]
    variants.each_with_index do |wrapper, index|
      group = contact_information
      group = group.sub('</h2>', '</h2><input type="email"><button>Update account</button>') if index == 4
      footer = "<footer>#{wrapper.sub("GROUP", group)}</footer>"
      with_url_page('https://publication.example.test/archive/', contact_collection_page(footer)) do |page|
        body = page.evaluate('document.body.innerHTML')
        payload = extract_payload(page)
        expect(payload.fetch('html')).not_to include('Open Research Foundation', 'office@publication.example.test')
        expect(payload.fetch('markdown')).not_to include('Open Research Foundation', 'office@publication.example.test')
        expect(page.evaluate('document.body.innerHTML')).to eq(body)
      end
    end
  end

  it 'preserves a labeled telephone destination and literal program text without admitting invalid schemes or telephone parameters' do
    program = 'const example = "tel:+12025550145?not_a_phone_parameter";'
    invalid = ['tel:+12025550145?subject=ignored', 'tel:+1202%0A5550145', 'tel:office', 'javascript:alert(1)']
    links = invalid.each_with_index.map { |href, index| "<a href='#{href}'>Invalid destination #{index}</a>" }.join(' ')
    html = <<~HTML
      <html><head><title>Calling the publication office</title><meta property="og:type" content="article"></head><body>
        <article><h1>Calling the publication office</h1>
          <p>The publication provides this telephone reference for readers who need further information about its research materials.
            <a href="tel:(+1)%20202%20555%200145">(+1) 202 555 0145</a>
          </p>
          <p>These examples explain unsupported destinations while keeping every authored label readable: #{links}</p>
          <pre><code>#{program}</code></pre>
        </article>
      </body></html>
    HTML
    with_url_page('https://publication.example.test/calling/', html) do |page|
      body = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      output = Nokogiri::HTML5.fragment(payload.fetch('html'))
      expect(output.css('a[href]').map { |link| link['href'] }).to eq(['tel:(+1)%20202%20555%200145'])
      expect(output.css('pre').map(&:text)).to eq([program])
      expect(payload.fetch('markdown')).to include('](tel:(+1)%20202%20555%200145)')
      expect(payload.fetch('markdown')).to include(program)
      expect(output.text).to include(*invalid.each_index.map { |index| "Invalid destination #{index}" })
      expect(page.evaluate('document.body.innerHTML')).to eq(body)
    end
  end
end
