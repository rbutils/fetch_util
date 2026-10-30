require 'open3'

RSpec.describe 'Physically owned narrative route material' do
  include_context 'extractor integration helpers'

  def narrative_route_page(extra = '', issue_attributes: '')
    sections = (1..2).map do |section|
      records = (1..3).map do |number|
        index = (section - 1) * 3 + number
        <<~HTML
          <article><a class="article-link" href="/volume/42/account-#{index}?edition=full&amp;view=text#report">
            <h3>Independent account number #{index}</h3>
            <p>Author #{index} describes a complete independently published account.</p>
          </a></article>
        HTML
      end.join
      "<h2 class='post-category'>Research section #{section}</h2>#{records}"
    end.join
    <<~HTML
      <html><head><title>Current journal and independent accounts</title>
        <meta name="generator" content="WordPress 6.8">
        <link rel="canonical" href="https://periodical.example.test/">
      </head><body><main><section class="content">
        <h1>Current journal and independent accounts</h1>
        <div class="toc"><div class="widget module-issue-toc">
          <section class="inner" #{issue_attributes}>
            <figure class="cover"><a href="/volume/42?edition=full&amp;view=text#contents">
              <img src="/covers/42.jpg?size=full&amp;theme=light#art" alt="Cover for volume 42">
            </a></figure>
            <span class="hed">Current volume</span>
            <h2 class="issue-name"><a href="/volume/42?edition=full&amp;view=text#contents">Field Notes</a></h2>
          </section>
        </div></div>
        <div class="widget module-issue-toc"><section class="article-toc">#{sections}</section></div>
        #{extra}
      </section></main></body></html>
    HTML
  end

  def observe_narrative_routes(html)
    with_url_page('https://periodical.example.test/', html) do |page|
      before = page.evaluate('document.body.outerHTML')
      payload = extract_payload(page, reader_mode: true)
      rendered, error, status = Open3.capture3(
        'python3', '-c',
        "from markdown_it import MarkdownIt; import sys; print(MarkdownIt('commonmark').enable('table').render(sys.stdin.read()), end='')",
        stdin_data: payload.fetch('markdown')
      )
      raise error unless status.success?
      expect(page.evaluate('document.body.outerHTML')).to eq(before)
      yield Nokogiri::HTML5.fragment(payload.fetch('html')), Nokogiri::HTML5.fragment(rendered)
    end
  end

  (0..2).each do |index|
    it "preserves six complete narrative records in source variant #{index}" do
      extra = index == 1 ? <<~HTML : ''
        <p><a href="/volume/42?edition=full&amp;view=text#contents">An independent volume reference</a></p>
        <pre><code>first_value('&lt;kept&gt;')

        last_value('&amp;complete')</code></pre>
      HTML
      attributes = index == 2 ? 'style="display:none"' : ''
      observe_narrative_routes(narrative_route_page(extra, issue_attributes: attributes)) do |native, markdown|
        [native, markdown].each do |node|
          expect(node.css('h1').map(&:text)).to eq(['Current journal and independent accounts'])
          expect(node.css('h3').map { |heading| heading.text.strip }).to eq(
            (1..6).map { |number| "Independent account number #{number}" }
          )
          expect(node.css('a[href]').map { |link| link['href'] }.select { |href| href.include?('/account-') }).to eq(
            (1..6).map { |number| "https://periodical.example.test/volume/42/account-#{number}?edition=full&view=text#report" }
          )
          expect(node.css('p').map { |paragraph| paragraph.text.strip }).to include(
            *(1..6).map { |number| "Author #{number} describes a complete independently published account." }
          )
          headings = ['Research section 1', 'Research section 2']
          headings.unshift('Field Notes') unless index == 2
          expect(node.css('h2').map(&:text)).to eq(headings)
          destination = 'https://periodical.example.test/volume/42?edition=full&view=text#contents'
          expected_references = [2, 3, 0].fetch(index)
          expect(node.css('a[href]').count { |link| link['href'] == destination }).to eq(expected_references)
          images = if index == 2
                     []
                   else
                     [['https://periodical.example.test/covers/42.jpg?size=full&theme=light#art', 'Cover for volume 42']]
                   end
          expect(node.css('img').map { |image| [image['src'], image['alt']] }).to eq(images)
          expect(node.text).to include('Current volume') unless index == 2
        end
        if index == 1
          program = "first_value('<kept>')\n\nlast_value('&complete')"
          expect(native.css('pre').map(&:text)).to eq([program])
          expect(markdown.css('pre').map(&:text)).to eq(["#{program}\n"])
        elsif index == 2
          expect(markdown.text).not_to include('Field Notes', 'Current volume')
          expect(markdown.css('img')).to be_empty
        end
      end
    end
  end

  it 'continues to reject genuine account navigation and form controls' do
    html = narrative_route_page.gsub('/account-', '/report-').sub('</main>', <<~HTML)
      <nav><a href="/account/profile"><h3>Manage account</h3><p>Change your account settings.</p></a></nav>
      <form action="/account/login"><label>Member account<input name="identity"></label><button>Sign in</button></form>
      </main>
    HTML
    observe_narrative_routes(html) do |_native, markdown|
      expect(markdown.text).not_to include('Manage account', 'Change your account settings.', 'Member account', 'Sign in')
      expect(markdown.css('a[href]').map { |link| link['href'] }).not_to include(
        'https://periodical.example.test/account/profile', 'https://periodical.example.test/account/login'
      )
    end
  end

  def narrative_feed_page(promotions: false, records: true, sectioned: false, narrative_routes: nil, record_count: 6)
    entries = if records
                (1..record_count).map do |number|
                  route = narrative_routes ? narrative_routes.fetch(number - 1) : "/volume/42/account-#{number}"
                  <<~HTML
                    <article><a class="article-link" href="#{route}?edition=full&amp;view=text#report">
                      <h3>Independent account number #{number}</h3>
                      <p>Author #{number} describes a complete independently published account.</p>
                    </a></article>
                  HTML
                end
              else
                []
              end
    offers = if promotions
               [
                 ['/subscribe?plan=annual', 'Subscribe today', 'Get every issue delivered to your door with a yearly subscription.'],
                 ['/newsletter/signup', 'Join our newsletter', 'Receive the best of our reporting in your inbox each week.'],
                 ['/account/upgrade', 'Become a member', 'Unlock unlimited reading and member-only events with a premium membership.'],
                 ['/settings/notifications', 'Notification preferences', 'Choose how and when we contact you about new stories.'],
                 ['/subscription/gift', 'Give the gift of reading', 'Send a year of our journalism to someone you care about.'],
                 ['/account-history/account/settings', 'Manage your account', 'Change the delivery settings for your account.']
               ].map { |href, heading, paragraph| "<article><a href='#{href}'><h3>#{heading}</h3><p>#{paragraph}</p></a></article>" }.join
             else
               ''
             end
    body = if sectioned
             "<section><h2>Research section 1</h2>#{entries.first(3).join}</section>" \
               "<section><h2>Research section 2</h2>#{entries.drop(3).join}#{offers}</section>"
           else
             "<section class='feed'><h2>#{records ? "Research" : "Offers"}</h2>#{entries.join}#{offers}</section>"
           end
    <<~HTML
      <html><head><title>Current journal and independent accounts</title>
        <link rel="canonical" href="https://periodical.example.test/">
      </head><body><main><section class="content"><h1>Current journal and independent accounts</h1>
        #{body}
      </section></main></body></html>
    HTML
  end

  it 'preserves all physical H3 records after repeated-record identity has been applied' do
    observe_narrative_routes(narrative_feed_page) do |_native, markdown|
      expect(markdown.css('h1').map(&:text)).to eq(['Current journal and independent accounts'])
      expect(markdown.css('h3').map(&:text)).to eq((1..6).map { |number| "Independent account number #{number}" })
      expect(markdown.css('a[href]').map { |link| link['href'] }).to eq(
        (1..6).map { |number| "https://periodical.example.test/volume/42/account-#{number}?edition=full&view=text#report" }
      )
    end
  end

  [false, true].each do |sectioned|
    it "rejects complete-shaped promotional action records in a #{sectioned ? "sectioned" : "flat"} narrative feed" do
      observe_narrative_routes(narrative_feed_page(promotions: true, sectioned: sectioned)) do |_native, markdown|
        expect(markdown.css('h3').map(&:text)).to eq((1..6).map { |number| "Independent account number #{number}" })
        expect(markdown.css('a[href]').map { |link| link['href'] }).to eq(
          (1..6).map { |number| "https://periodical.example.test/volume/42/account-#{number}?edition=full&view=text#report" }
        )
        expect(markdown.css('p').map(&:text)).to include(
          *(1..6).map { |number| "Author #{number} describes a complete independently published account." }
        )
      end
    end
  end

  it 'does not promote an action-only collection to authored narrative records' do
    observe_narrative_routes(narrative_feed_page(promotions: true, records: false)) do |_native, markdown|
      expect(markdown.css('a[href]')).to be_empty
    end
  end

  it 'admits complete narrative slugs across the existing route-word vocabulary' do
    routes = %w[/news/account-takeover-attacks /news/settings-leak-analysis /news/newsletter-publisher-award
                /news/subscription-prices-rise /news/login-page-redesign /news/register-architecture-review]
    observe_narrative_routes(narrative_feed_page(narrative_routes: routes)) do |_native, markdown|
      expect(markdown.css('h3').map(&:text)).to eq((1..6).map { |number| "Independent account number #{number}" })
      expect(markdown.css('a[href]').map { |link| link['href'] }).to eq(
        routes.map { |route| "https://periodical.example.test#{route}?edition=full&view=text#report" }
      )
    end
  end

  it 'keeps action cards out of the independent homepage lead fallback' do
    routes = %w[/news/account-takeover-attacks /news/settings-leak-analysis
                /news/newsletter-publisher-award /news/subscription-prices-rise]
    html = narrative_feed_page(promotions: true, narrative_routes: routes, record_count: 4)
           .sub('Research</h2>', 'Latest research</h2>')
    observe_narrative_routes(html) do |_native, markdown|
      expect(markdown.css('h1').map(&:text)).to eq(['Current journal and independent accounts'])
      expect(markdown.css('h3').map(&:text)).to eq((1..4).map { |number| "Independent account number #{number}" })
      expect(markdown.css('a[href]').map { |link| link['href'] }).to eq(
        routes.map { |route| "https://periodical.example.test#{route}?edition=full&view=text#report" }
      )
      expect(markdown.css('p').map(&:text)).to include(
        *(1..4).map { |number| "Author #{number} describes a complete independently published account." }
      )
    end
  end
end
